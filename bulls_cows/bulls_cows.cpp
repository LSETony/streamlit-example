// Быки и коровы: компьютер отгадывает загаданное пользователем число.
//
// Сборка:   g++ -std=c++17 -O2 -o bulls_cows bulls_cows.cpp
// Запуск:   ./bulls_cows            игра (ходы случайно «перемешаны», см. ниже)
//           ./bulls_cows -f         игра без перемешивания: всегда начинает с 2135
//           ./bulls_cows -z         разрешить 0 первой цифрой (5040 чисел вместо 4536)
//           ./bulls_cows -t [-f]    самопроверка: сыграть со всеми числами и вывести статистику
//           ./bulls_cows -b         пересчитать таблицу вторых ходов SECOND_GUESS
//
// Алгоритм.
// 1. «Алфавит» и вычёркивание цифр в полном виде: храним список всех чисел,
//    которые ещё не противоречат ни одному ответу (кандидаты). После каждого
//    ответа (позиции быков + количество коров) вычёркиваем несовместимые числа.
//    Так автоматически учитываются и «цифры, которые 100% мимо», и
//    «зафиксированные» быки, и все более тонкие выводы.
// 2. Первый ход 2135. Дальше фиксированной серии (4357, 6579, 8790) нет:
//    по симуляции она даёт в среднем 5.39 хода против 4.58 у адаптивного выбора,
//    потому что тратит ходы, когда кандидатов уже осталось мало.
// 3. Следующая попытка выбирается среди ВСЕХ чисел, не только среди кандидатов:
//    - много кандидатов (> ROLLOUT_MAX) — максимум энтропии: ход, ответы на который
//      делят кандидатов на как можно более мелкие и ровные группы;
//    - средне (EXACT_MAX..ROLLOUT_MAX) — берём ROLLOUT_K лучших по энтропии ходов
//      и для каждого достраиваем дерево игры до конца, выбираем ход с наименьшей
//      глубиной худшего случая, а при равенстве с наименьшим суммарным числом ходов;
//    - мало (<= EXACT_MAX) — полный перебор с запоминанием (оптимальное дерево).
// 4. Защита от анализа кода соперниками: при каждом запуске цифры 1..9 случайно
//    переставляются между собой, а позиции 2..4 — между собой. Множество допустимых
//    чисел при этом не меняется, качество игры тоже, но заранее рассчитать
//    «неудобное» для программы число по исходнику нельзя.

#include <algorithm>
#include <climits>
#include <cstdint>
#include <cmath>
#include <iostream>
#include <map>
#include <numeric>
#include <random>
#include <set>
#include <sstream>
#include <string>
#include <vector>

#ifdef _WIN32
#include <windows.h>
#endif

using namespace std;

const string FIRST_GUESS = "2135";
const int EXACT_MAX = 20;     // до стольких кандидатов — точный перебор
const int EXACT_EXTRA = 10;   // сколько «не кандидатов» пробовать в переборе
const int ROLLOUT_MAX = 600;  // до стольких кандидатов — просмотр вперёд
const int ROLLOUT_K = 60;     // сколько ходов сравнивать при просмотре вперёд

const int WIN = 15 * 8;  // ответ «4 быка»: маска 1111, 0 коров
const int NFB = 16 * 8;  // ответ кодируется как маска_быков * 8 + коровы

int N;                   // количество допустимых чисел
vector<string> codes;    // допустимые числа
vector<uint8_t> FB;      // FB[g * N + s] — ответ на попытку g при загаданном s
// Энтропия считается в целых числах (k*log2(k) * 2^20, округлено), чтобы
// результат был одинаковым на любом компьютере и совпадал с Python-версией.
const long long SCALE = 1 << 20;
vector<long long> ENT;   // ENT[k] = round(k * log2(k) * SCALE)
int first_guess = -1;    // индекс первого хода (образ 2135 при перемешивании)

inline int fb(int g, int s) { return FB[(size_t)g * N + s]; }

int feedback_code(const string& secret, const string& guess) {
    int mask = 0, common = 0, bulls = 0;
    for (int i = 0; i < 4; ++i) {
        if (secret[i] == guess[i]) { mask |= 1 << i; ++bulls; }
        if (secret.find(guess[i]) != string::npos) ++common;
    }
    return mask * 8 + (common - bulls);
}

// Строит список чисел. Перестановка цифр digit_map и позиций pos_map
// сохраняет множество допустимых чисел, поэтому игра «в перемешанных
// обозначениях» ровно так же сильна, как исходная.
void init(bool allow_zero, bool shuffle) {
    string digit_map = "0123456789";
    int pos_map[4] = {0, 1, 2, 3};
    if (shuffle) {
        mt19937 rng(random_device{}());
        // Без ведущего нуля цифра 0 и первая позиция особые: их не трогаем.
        int from = allow_zero ? 0 : 1;
        std::shuffle(digit_map.begin() + from, digit_map.end(), rng);
        std::shuffle(pos_map + from, pos_map + 4, rng);
    }

    codes.clear();
    for (int x = 0; x < 10000; ++x) {
        string s = to_string(10000 + x).substr(1);
        if (set<char>(s.begin(), s.end()).size() != 4) continue;
        if (!allow_zero && s[0] == '0') continue;
        if (s == FIRST_GUESS) first_guess = codes.size();
        string t(4, ' ');
        for (int i = 0; i < 4; ++i) t[pos_map[i]] = digit_map[s[i] - '0'];
        codes.push_back(t);
    }
    N = codes.size();
    ENT.assign(N + 1, 0);
    for (int k = 2; k <= N; ++k) ENT[k] = llround(k * log2((double)k) * SCALE);
    FB.assign((size_t)N * N, 0);
    for (int g = 0; g < N; ++g)
        for (int s = 0; s < N; ++s)
            FB[(size_t)g * N + s] = feedback_code(codes[s], codes[g]);
}

vector<vector<int>> split(int g, const vector<int>& c) {
    vector<vector<int>> parts(NFB);
    for (int s : c) parts[fb(g, s)].push_back(s);
    return parts;
}

// Меньше — лучше: сумма k*log2(k) по группам ответов (= n*log2(n) - n*энтропия).
// Попытка-кандидат получает небольшой бонус: она может сразу оказаться ответом.
// Считаем в целых числах, см. ENT.

long long entropy_score(int g, const vector<int>& c, const vector<char>& is_cand) {
    int cnt[NFB] = {0};
    for (int s : c) ++cnt[fb(g, s)];
    long long e = 0;
    for (int k : cnt) e += ENT[k];
    return e - (is_cand[g] ? SCALE / 2 : 0);
}

vector<char> candidate_flags(const vector<int>& c) {
    vector<char> is_cand(N, 0);
    for (int s : c) is_cand[s] = 1;
    return is_cand;
}

// Ходы, отсортированные по энтропии (лучшие первыми).
vector<int> ranked_guesses(const vector<int>& c) {
    vector<char> is_cand = candidate_flags(c);
    vector<pair<long long, int>> sc(N);
    for (int g = 0; g < N; ++g) sc[g] = {entropy_score(g, c, is_cand), g};
    sort(sc.begin(), sc.end());
    vector<int> res(N);
    for (int i = 0; i < N; ++i) res[i] = sc[i].second;
    return res;
}

// Результат для множества кандидатов: суммарное число ходов (по всем
// кандидатам, считая ход, на котором число угадано), высота дерева и ход.
struct Plan { long long cost; int height; int guess; };

map<vector<int>, Plan> memo;

// Точный перебор для небольших множеств.
Plan exact(const vector<int>& c) {
    int n = c.size();
    if (n == 1) return {1, 1, c[0]};
    if (n == 2) return {3, 2, c[0]};
    auto it = memo.find(c);
    if (it != memo.end()) return it->second;

    vector<char> is_cand = candidate_flags(c);
    vector<int> pool;
    int extra = 0;
    for (int g : ranked_guesses(c)) {
        if (is_cand[g]) pool.push_back(g);
        else if (extra < EXACT_EXTRA) { pool.push_back(g); ++extra; }
    }

    Plan best{LLONG_MAX, INT_MAX, -1};
    for (int g : pool) {
        auto parts = split(g, c);
        if ((int)parts[fb(g, c[0])].size() == n && !is_cand[g]) continue;  // ход ничего не даёт
        // Нижняя оценка: в группе из m чисел нужно минимум 2m-1 ходов.
        long long lb = n;
        for (int k = 0; k < NFB; ++k)
            if (k != WIN && !parts[k].empty()) lb += 2 * (long long)parts[k].size() - 1;
        if (lb > best.cost) continue;

        long long cost = n;
        int height = 1;
        for (int k = 0; k < NFB && cost <= best.cost; ++k) {
            if (k == WIN || parts[k].empty()) continue;
            Plan p = exact(parts[k]);
            cost += p.cost;
            height = max(height, p.height + 1);
        }
        if (cost < best.cost || (cost == best.cost && height < best.height))
            best = {cost, height, g};
    }
    return memo[c] = best;
}

Plan greedy(const vector<int>& c);

// Стоимость хода g: дерево под ним достраивается «жадно» до конца.
Plan evaluate(int g, const vector<int>& c) {
    auto parts = split(g, c);
    Plan res{(long long)c.size(), 1, g};
    for (int k = 0; k < NFB; ++k) {
        if (k == WIN || parts[k].empty()) continue;
        Plan p = greedy(parts[k]);
        res.cost += p.cost;
        res.height = max(res.height, p.height + 1);
    }
    return res;
}

Plan greedy(const vector<int>& c) {
    if ((int)c.size() <= EXACT_MAX) return exact(c);
    return evaluate(ranked_guesses(c)[0], c);
}

// Второй ход считается дольше всего (несколько секунд), поэтому он рассчитан
// заранее этой же программой (ключ -b) и записан таблицей: после ответа на
// первый ход кандидаты образуют одну из групп, группа узнаётся по номеру её
// первого числа. Номера не зависят от перемешивания, поэтому таблица верна
// при любом запуске (кроме режима -z, где список чисел другой).
bool use_book = true;
const map<int, int> SECOND_GUESS = {
    {1544, 1544},
    {17, 1536},
    {1, 178},
    {0, 127},
    {78, 134},
    {521, 1544},
    {505, 1513},
    {504, 1513},
    {638, 638},
    {1571, 1796},
    {1065, 1206},
    {1064, 1206},
    {1086, 1086},
    {561, 1544},
    {560, 1536},
    {582, 582},
    {1529, 1544},
    {8, 197},
    {7, 197},
    {239, 239},
    {512, 1544},
    {511, 1540},
    {743, 743},
    {1582, 1827},
    {1583, 1829},
    {2087, 2087},
    {567, 17},
    {1543, 1544},
    {16, 178},
    {2, 178},
    {121, 121},
    {520, 1544},
    {506, 1515},
    {625, 625},
    {1570, 1796},
    {1066, 1025},
    {1073, 1073},
    {562, 17},
    {1528, 1544},
    {9, 17},
    {65, 65},
    {513, 17},
    {1584, 1544}
};

bool better(const Plan& a, const Plan& b) {
    return a.height < b.height || (a.height == b.height && a.cost < b.cost);
}

int choose_guess(const vector<int>& c, int turn) {
    if (turn == 1) return first_guess;
    if (turn == 2 && use_book) {
        auto it = SECOND_GUESS.find(c[0]);
        if (it != SECOND_GUESS.end()) return it->second;
    }
    int n = c.size();
    if (n <= EXACT_MAX) return exact(c).guess;
    vector<int> ranked = ranked_guesses(c);
    if (n > ROLLOUT_MAX) return ranked[0];

    Plan best{LLONG_MAX, INT_MAX, -1};
    for (int i = 0; i < ROLLOUT_K && i < N; ++i) {
        Plan p = evaluate(ranked[i], c);
        if (best.guess < 0 || better(p, best)) best = p;
    }
    return best.guess;
}

// ----------------------------------------------------------------------------
// Ввод-вывод

string trim(const string& s) {
    size_t b = s.find_first_not_of(" \t\r\n");
    if (b == string::npos) return "";
    size_t e = s.find_last_not_of(" \t\r\n");
    return s.substr(b, e - b + 1);
}

// Позиции быков: «2,4», «2 4» или «24». Пустая строка — быков нет.
bool parse_bulls_positions(const string& raw, int& mask, string& error) {
    mask = 0;
    for (char ch : raw) {
        if (ch == ',' || ch == ' ' || ch == '\t' || ch == '\r') continue;
        if (ch < '1' || ch > '4') {
            error = "Позиции должны быть от 1 до 4, например 2,4, или пусто.";
            return false;
        }
        mask |= 1 << (ch - '1');
    }
    return true;
}

bool parse_cows(const string& raw, int& cows) {
    string s = trim(raw);
    if (s.empty()) { cows = 0; return true; }
    if (s.size() != 1 || s[0] < '0' || s[0] > '4') return false;
    cows = s[0] - '0';
    return true;
}

int play_interactive(bool allow_zero) {
    vector<int> candidates(N);
    iota(candidates.begin(), candidates.end(), 0);

    cout << "Загадайте четырёхзначное число из разных цифр"
         << (allow_zero ? " (0 может быть первой).\n" : " (первая цифра не 0).\n");
    cout << "Позиции быков вводите с 1 по 4, например: 2,4 (пусто — быков нет).\n";
    cout << "Количество коров — число от 0 до 4 (пусто — 0).\n";

    for (int turn = 1;; ++turn) {
        int g = choose_guess(candidates, turn);
        const string& guess = codes[g];
        cout << "\nХод " << turn << ": " << guess
             << "   (возможных чисел: " << candidates.size() << ")\n";

        while (true) {
            string raw;
            cout << "Позиции быков: " << flush;
            if (!getline(cin, raw)) return 1;
            int mask;
            string error;
            if (!parse_bulls_positions(raw, mask, error)) { cout << error << "\n"; continue; }
            int bulls = 0;
            for (int i = 0; i < 4; ++i) bulls += mask >> i & 1;

            int cows = 0;
            if (bulls < 4) {
                cout << "Количество коров: " << flush;
                if (!getline(cin, raw)) return 1;
                if (!parse_cows(raw, cows) || bulls + cows > 4) {
                    cout << "Такое количество коров невозможно, повторите ответ.\n";
                    continue;
                }
            }

            int answer = mask * 8 + cows;
            if (answer == WIN) {
                cout << "Угадано за " << turn << " "
                     << (turn == 1 ? "ход" : turn < 5 ? "хода" : "ходов") << ": " << guess << "!\n";
                return 0;
            }

            vector<int> filtered;
            for (int s : candidates)
                if (fb(g, s) == answer) filtered.push_back(s);
            if (filtered.empty()) {
                cout << "Такого не может быть с учётом прошлых ответов. Проверьте и повторите.\n";
                continue;
            }
            candidates.swap(filtered);
            break;
        }
    }
}

// Печать таблицы вторых ходов (для SECOND_GUESS).
void print_book() {
    use_book = false;
    vector<int> all(N);
    iota(all.begin(), all.end(), 0);
    auto parts = split(first_guess, all);
    for (int k = 0; k < NFB; ++k) {
        if (k == WIN || parts[k].empty()) continue;
        cout << "    {" << parts[k][0] << ", " << choose_guess(parts[k], 2) << "},\n";
    }
}

// Самопроверка: сыграть со всеми возможными числами.
void self_test() {
    vector<int> all(N);
    iota(all.begin(), all.end(), 0);
    long long total = 0;
    int worst = 0;
    map<int, int> hist;
    string worst_example;

    // Обход дерева игры: все числа с одинаковыми ответами идут одним путём.
    vector<pair<vector<int>, int>> stack{{all, 1}};
    while (!stack.empty()) {
        auto [c, turn] = stack.back();
        stack.pop_back();
        int g = choose_guess(c, turn);
        auto parts = split(g, c);
        for (int k = 0; k < NFB; ++k) {
            if (parts[k].empty()) continue;
            if (k == WIN) {
                total += turn;
                ++hist[turn];
                if (turn > worst) { worst = turn; worst_example = codes[g]; }
            } else {
                stack.push_back({parts[k], turn + 1});
            }
        }
    }

    cout << "Чисел: " << N << "\n";
    cout << "Всего ходов: " << total << ", в среднем: " << (double)total / N << "\n";
    cout << "Худший случай: " << worst << " ходов (например, " << worst_example << ")\n";
    cout << "Распределение (ходов: чисел):";
    for (auto [turns, count] : hist) cout << "  " << turns << ": " << count;
    cout << "\n";
}

int main(int argc, char** argv) {
#ifdef _WIN32
    SetConsoleOutputCP(CP_UTF8);
    SetConsoleCP(CP_UTF8);
#endif
    bool allow_zero = false, shuffle = true, test = false, book = false;
    for (int i = 1; i < argc; ++i) {
        string a = argv[i];
        if (a == "-z") allow_zero = true;
        else if (a == "-f") shuffle = false;
        else if (a == "-t") test = true;
        else if (a == "-b") book = true;
        else {
            cout << "Использование: " << argv[0] << " [-f] [-z] [-t] [-b]\n";
            return 1;
        }
    }

    init(allow_zero, shuffle);
    if (allow_zero) use_book = false;
    if (book) print_book();
    else if (test) self_test();
    else return play_interactive(allow_zero);
    return 0;
}
