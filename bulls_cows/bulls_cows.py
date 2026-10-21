"""Быки и коровы: компьютер отгадывает загаданное пользователем число.

Python-версия программы bulls_cows.cpp: тот же алгоритм, те же ходы.
Нужен numpy:  pip install numpy

Запуск:   python bulls_cows.py          игра (ходы случайно «перемешаны», см. ниже)
          python bulls_cows.py -f       игра без перемешивания: всегда начинает с 2135
          python bulls_cows.py -z       разрешить 0 первой цифрой (5040 чисел вместо 4536)
          python bulls_cows.py -t [-f]  самопроверка: сыграть со всеми числами
          python bulls_cows.py -b       пересчитать таблицу вторых ходов SECOND_GUESS

Алгоритм.
1. «Алфавит» и вычёркивание в полном виде: храним список всех чисел, которые
   ещё не противоречат ни одному ответу (кандидаты). После каждого ответа
   (позиции быков + количество коров) вычёркиваем несовместимые числа. Так
   автоматически учитываются и «цифры, которые 100% мимо», и «зафиксированные»
   быки, и все более тонкие выводы.
2. Первый ход 2135. Фиксированной серии дальше нет: она тратит ходы, когда
   кандидатов уже осталось мало (в среднем 5.39 хода против 4.58).
3. Следующая попытка выбирается среди ВСЕХ чисел, не только среди кандидатов:
   - много кандидатов (> ROLLOUT_MAX) — максимум энтропии: ход, ответы на который
     делят кандидатов на как можно более мелкие и ровные группы;
   - средне (EXACT_MAX..ROLLOUT_MAX) — берём ROLLOUT_K лучших по энтропии ходов
     и для каждого достраиваем дерево игры до конца, выбираем ход с наименьшей
     глубиной худшего случая, а при равенстве с наименьшим суммарным числом ходов;
   - мало (<= EXACT_MAX) — полный перебор с запоминанием (оптимальное дерево).
   Результат: любое число (первая цифра не 0) угадывается не позже 6-й попытки.
4. Защита от анализа кода соперниками: при каждом запуске цифры 1..9 случайно
   переставляются между собой, а позиции 2..4 — между собой. Множество допустимых
   чисел при этом не меняется, качество игры тоже, но заранее рассчитать
   «неудобное» для программы число по исходнику нельзя.
"""

import math
import random
import sys
from collections import Counter

import numpy as np

FIRST_GUESS = "2135"
EXACT_MAX = 20     # до стольких кандидатов — точный перебор
EXACT_EXTRA = 10   # сколько «не кандидатов» пробовать в переборе
ROLLOUT_MAX = 600  # до стольких кандидатов — просмотр вперёд
ROLLOUT_K = 60     # сколько ходов сравнивать при просмотре вперёд

WIN = 15 * 8  # ответ «4 быка»: маска 1111, 0 коров
NFB = 16 * 8  # ответ кодируется как маска_быков * 8 + коровы

# Энтропия считается в целых числах (k*log2(k) * 2^20, округлено), чтобы
# результат был одинаковым на любом компьютере и совпадал с C++-версией.
SCALE = 1 << 20

INF = float("inf")

codes = []        # допустимые числа
N = 0
FB = None         # FB[g, s] — ответ на попытку g при загаданном s
ENT = None        # ENT[k] = round(k * log2(k) * SCALE)
first_guess = -1  # индекс первого хода (образ 2135 при перемешивании)
use_book = True

# Второй ход считается дольше всего, поэтому он рассчитан заранее (ключ -b)
# и записан таблицей: после ответа на первый ход кандидаты образуют одну из
# групп, группа узнаётся по номеру её первого числа. Номера не зависят от
# перемешивания, поэтому таблица верна при любом запуске (кроме режима -z).
SECOND_GUESS = {
    1544: 1544,
    17: 1536,
    1: 178,
    0: 127,
    78: 134,
    521: 1544,
    505: 1513,
    504: 1513,
    638: 638,
    1571: 1796,
    1065: 1206,
    1064: 1206,
    1086: 1086,
    561: 1544,
    560: 1536,
    582: 582,
    1529: 1544,
    8: 197,
    7: 197,
    239: 239,
    512: 1544,
    511: 1540,
    743: 743,
    1582: 1827,
    1583: 1829,
    2087: 2087,
    567: 17,
    1543: 1544,
    16: 178,
    2: 178,
    121: 121,
    520: 1544,
    506: 1515,
    625: 625,
    1570: 1796,
    1066: 1025,
    1073: 1073,
    562: 17,
    1528: 1544,
    9: 17,
    65: 65,
    513: 17,
    1584: 1544,
}


def feedback_code(secret, guess):
    mask = common = bulls = 0
    for i in range(4):
        if secret[i] == guess[i]:
            mask |= 1 << i
            bulls += 1
        if guess[i] in secret:
            common += 1
    return mask * 8 + (common - bulls)


def init(allow_zero, shuffle):
    """Строит список чисел. Перестановка цифр и позиций сохраняет множество
    допустимых чисел, поэтому игра «в перемешанных обозначениях» ровно так же
    сильна, как исходная."""
    global codes, N, FB, ENT, first_guess
    digit_map = list("0123456789")
    pos_map = [0, 1, 2, 3]
    if shuffle:
        # Без ведущего нуля цифра 0 и первая позиция особые: их не трогаем.
        start = 0 if allow_zero else 1
        tail = digit_map[start:]
        random.shuffle(tail)
        digit_map[start:] = tail
        tail = pos_map[start:]
        random.shuffle(tail)
        pos_map[start:] = tail

    codes = []
    for x in range(10000):
        s = f"{x:04d}"
        if len(set(s)) != 4 or (not allow_zero and s[0] == "0"):
            continue
        if s == FIRST_GUESS:
            first_guess = len(codes)
        t = [" "] * 4
        for i in range(4):
            t[pos_map[i]] = digit_map[int(s[i])]
        codes.append("".join(t))
    N = len(codes)

    ENT = np.zeros(N + 1, dtype=np.int64)
    for k in range(2, N + 1):
        ENT[k] = math.floor(k * math.log2(k) * SCALE + 0.5)

    d = np.array([[int(ch) for ch in c] for c in codes], dtype=np.int8)
    g = d[:, None, :]  # попытка
    s = d[None, :, :]  # загаданное
    fb = np.zeros((N, N), dtype=np.int16)
    for i in range(4):
        fb += (g[:, :, i] == s[:, :, i]).astype(np.int16) * (8 << i)
    common = np.zeros((N, N), dtype=np.int16)
    for i in range(4):
        for j in range(4):
            common += g[:, :, i] == s[:, :, j]
    bulls = sum((g[:, :, i] == s[:, :, i]).astype(np.int16) for i in range(4))
    FB = (fb + common - bulls).astype(np.uint8)


def split(g, c):
    parts = [[] for _ in range(NFB)]
    for s, k in zip(c, FB[g, c].tolist()):
        parts[k].append(s)
    return parts


def ranked_guesses(c):
    """Ходы, отсортированные по энтропии (лучшие первыми). Меньше — лучше:
    сумма k*log2(k) по группам ответов. Попытка-кандидат получает небольшой
    бонус: она может сразу оказаться ответом."""
    n = len(c)
    sub = FB[:, c].astype(np.int64) + (np.arange(N, dtype=np.int64) * NFB)[:, None]
    counts = np.bincount(sub.ravel(), minlength=N * NFB).reshape(N, NFB)
    score = ENT[counts].sum(axis=1)
    score[c] -= SCALE // 2
    return np.argsort(score, kind="stable").tolist() if n else []


# План для множества кандидатов: (суммарное число ходов по всем кандидатам,
# считая ход, на котором число угадано; высота дерева; ход).
memo = {}


def exact(c):
    """Точный перебор для небольших множеств."""
    n = len(c)
    if n == 1:
        return (1, 1, c[0])
    if n == 2:
        return (3, 2, c[0])
    key = tuple(c)
    if key in memo:
        return memo[key]

    cand = set(c)
    pool = []
    extra = 0
    for g in ranked_guesses(c):
        if g in cand:
            pool.append(g)
        elif extra < EXACT_EXTRA:
            pool.append(g)
            extra += 1

    best = (INF, INF, -1)
    for g in pool:
        parts = split(g, c)
        if len(parts[FB[g, c[0]]]) == n and g not in cand:
            continue  # ход ничего не даёт
        # Нижняя оценка: в группе из m чисел нужно минимум 2m-1 ходов.
        lb = n + sum(2 * len(p) - 1 for k, p in enumerate(parts) if k != WIN and p)
        if lb > best[0]:
            continue
        cost, height = n, 1
        for k in range(NFB):
            if cost > best[0]:
                break
            if k == WIN or not parts[k]:
                continue
            p = exact(parts[k])
            cost += p[0]
            height = max(height, p[1] + 1)
        if cost < best[0] or (cost == best[0] and height < best[1]):
            best = (cost, height, g)
    memo[key] = best
    return best


def evaluate(g, c):
    """Стоимость хода g: дерево под ним достраивается «жадно» до конца."""
    cost, height = len(c), 1
    for k, part in enumerate(split(g, c)):
        if k == WIN or not part:
            continue
        p = greedy(part)
        cost += p[0]
        height = max(height, p[1] + 1)
    return (cost, height, g)


def greedy(c):
    if len(c) <= EXACT_MAX:
        return exact(c)
    return evaluate(ranked_guesses(c)[0], c)


def better(a, b):
    return a[1] < b[1] or (a[1] == b[1] and a[0] < b[0])


def choose_guess(c, turn):
    if turn == 1:
        return first_guess
    if turn == 2 and use_book and c[0] in SECOND_GUESS:
        return SECOND_GUESS[c[0]]
    n = len(c)
    if n <= EXACT_MAX:
        return exact(c)[2]
    ranked = ranked_guesses(c)
    if n > ROLLOUT_MAX:
        return ranked[0]

    best = None
    for g in ranked[:ROLLOUT_K]:
        p = evaluate(g, c)
        if best is None or better(p, best):
            best = p
    return best[2]


# ----------------------------------------------------------------------------
# Ввод-вывод

def parse_bulls_positions(raw):
    """Позиции быков: «2,4», «2 4» или «24». Пустая строка — быков нет."""
    mask = 0
    for ch in raw:
        if ch in ", \t\r":
            continue
        if ch not in "1234":
            return None
        mask |= 1 << (int(ch) - 1)
    return mask


def parse_cows(raw):
    s = raw.strip()
    if not s:
        return 0
    if len(s) != 1 or s not in "01234":
        return None
    return int(s)


def turns_word(n):
    return "ход" if n == 1 else "хода" if n < 5 else "ходов"


def play_interactive(allow_zero):
    candidates = list(range(N))

    print("Загадайте четырёхзначное число из разных цифр"
          + (" (0 может быть первой)." if allow_zero else " (первая цифра не 0)."))
    print("Позиции быков вводите с 1 по 4, например: 2,4 (пусто — быков нет).")
    print("Количество коров — число от 0 до 4 (пусто — 0).")

    turn = 0
    while True:
        turn += 1
        g = choose_guess(candidates, turn)
        guess = codes[g]
        print(f"\nХод {turn}: {guess}   (возможных чисел: {len(candidates)})")

        while True:
            try:
                raw = input("Позиции быков: ")
            except EOFError:
                return 1
            mask = parse_bulls_positions(raw)
            if mask is None:
                print("Позиции должны быть от 1 до 4, например 2,4, или пусто.")
                continue
            bulls = bin(mask).count("1")

            cows = 0
            if bulls < 4:
                try:
                    raw = input("Количество коров: ")
                except EOFError:
                    return 1
                cows = parse_cows(raw)
                if cows is None or bulls + cows > 4:
                    print("Такое количество коров невозможно, повторите ответ.")
                    continue

            answer = mask * 8 + cows
            if answer == WIN:
                print(f"Угадано за {turn} {turns_word(turn)}: {guess}!")
                return 0

            filtered = [s for s, k in zip(candidates, FB[g, candidates].tolist()) if k == answer]
            if not filtered:
                print("Такого не может быть с учётом прошлых ответов. Проверьте и повторите.")
                continue
            candidates = filtered
            break


def print_book():
    """Печать таблицы вторых ходов (для SECOND_GUESS)."""
    global use_book
    use_book = False
    parts = split(first_guess, list(range(N)))
    for k, part in enumerate(parts):
        if k != WIN and part:
            print(f"    {part[0]}: {choose_guess(part, 2)},", flush=True)


def self_test():
    """Самопроверка: сыграть со всеми возможными числами."""
    total = worst = 0
    worst_example = ""
    hist = Counter()

    # Обход дерева игры: все числа с одинаковыми ответами идут одним путём.
    stack = [(list(range(N)), 1)]
    while stack:
        c, turn = stack.pop()
        g = choose_guess(c, turn)
        for k, part in enumerate(split(g, c)):
            if not part:
                continue
            if k == WIN:
                total += turn
                hist[turn] += 1
                if turn > worst:
                    worst, worst_example = turn, codes[g]
            else:
                stack.append((part, turn + 1))

    print(f"Чисел: {N}")
    print(f"Всего ходов: {total}, в среднем: {total / N:.4f}")
    print(f"Худший случай: {worst} ходов (например, {worst_example})")
    print("Распределение (ходов: чисел):"
          + "".join(f"  {t}: {hist[t]}" for t in sorted(hist)))


def main():
    global use_book
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    args = sys.argv[1:]
    if any(a not in ("-f", "-z", "-t", "-b") for a in args):
        print(f"Использование: {sys.argv[0]} [-f] [-z] [-t] [-b]")
        return 1
    allow_zero = "-z" in args
    init(allow_zero, shuffle="-f" not in args)
    if allow_zero:
        use_book = False
    if "-b" in args:
        print_book()
    elif "-t" in args:
        self_test()
    else:
        return play_interactive(allow_zero)
    return 0


if __name__ == "__main__":
    sys.exit(main())
