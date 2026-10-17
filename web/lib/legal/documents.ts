import { COMPANY } from "./company";

// Тексты юридических страниц на русском и английском. Это стартовая редакция: перед запуском её должен проверить юрист
// в каждой стране присутствия. Тексты не проходят через словарь интерфейса — у каждой версии свой полный текст.

export interface LegalDoc {
  title: string;
  intro: string;
  sections: { h: string; p: string[] }[];
}

const contact = `${COMPANY.legalName}, ${COMPANY.registration}, ${COMPANY.address}. Email: ${COMPANY.email}`;

export const TERMS: Record<"ru" | "en", LegalDoc> = {
  en: {
    title: "Terms of Service",
    intro: "These terms govern the use of core., a software service for gyms and fitness studios, and the core. member app. By creating an account you accept these terms on behalf of your business.",
    sections: [
      { h: "1. The service", p: [
        "core. provides a web dashboard for gym owners and staff (members, passes, check-in, schedule, payments, reports) and a mobile app for gym members.",
        "We may improve and change the service. We will notify you in advance of changes that materially reduce its functionality.",
      ] },
      { h: "2. Accounts", p: [
        "You must provide accurate information and keep login details confidential. You are responsible for actions taken by your staff accounts.",
        "The account owner decides which staff members have access and with which role.",
      ] },
      { h: "3. Trial, plans and payment", p: [
        "New gyms get a free trial. After the trial, continued use requires a paid plan. If the plan is not paid, the dashboard switches to read-only mode; your data is kept.",
        "Prices and plan contents are shown at the time of purchase. Fees are non-refundable except where required by law.",
      ] },
      { h: "4. Your data and your members' data", p: [
        "You own the data you enter into core. You are the controller of your members' personal data and are responsible for having a lawful basis and the required consents to process it.",
        "We process your members' data only on your instructions and only to provide the service, as described in our Privacy Policy.",
        "You can export your client list at any time. After you close your account, we delete your data within a reasonable period unless the law requires us to keep it.",
      ] },
      { h: "5. Payments to your gym", p: [
        "Online payments from members go directly to your account with the payment provider you connect (for example YooKassa in Russia). core. is not a party to these payments and does not hold your funds.",
      ] },
      { h: "6. Acceptable use", p: [
        "You must not use core. to break the law, send spam, access other customers' data, or interfere with the service.",
      ] },
      { h: "7. Availability and liability", p: [
        "We work to keep core. available and secure but do not guarantee uninterrupted operation. To the extent permitted by law, our total liability is limited to the fees you paid in the 12 months before the claim.",
      ] },
      { h: "8. Termination", p: [
        "You may stop using core. at any time. We may suspend accounts that breach these terms, after notice where possible.",
      ] },
      { h: "9. Contact", p: [contact] },
    ],
  },
  ru: {
    title: "Условия использования",
    intro: "Эти условия регулируют использование core. — сервиса для фитнес-залов и студий — и приложения core. для клиентов. Создавая аккаунт, вы принимаете условия от имени своего бизнеса.",
    sections: [
      { h: "1. Сервис", p: [
        "core. — веб-кабинет для владельцев и сотрудников залов (клиенты, абонементы, отметка визитов, расписание, оплаты, отчёты) и мобильное приложение для клиентов зала.",
        "Мы можем улучшать и менять сервис. Об изменениях, которые заметно сокращают его возможности, мы предупредим заранее.",
      ] },
      { h: "2. Аккаунты", p: [
        "Указывайте достоверные данные и не передавайте логины посторонним. Вы отвечаете за действия, совершённые с аккаунтов ваших сотрудников.",
        "Владелец аккаунта сам решает, кому из сотрудников дать доступ и с какой ролью.",
      ] },
      { h: "3. Пробный период, тарифы и оплата", p: [
        "Новые залы получают бесплатный пробный период. Дальше для работы нужен оплаченный тариф. Если тариф не оплачен, кабинет переходит в режим «только чтение», данные сохраняются.",
        "Цены и состав тарифов указываются при покупке. Оплата не возвращается, кроме случаев, предусмотренных законом.",
      ] },
      { h: "4. Ваши данные и данные ваших клиентов", p: [
        "Данные, которые вы вносите в core., принадлежат вам. Оператором персональных данных ваших клиентов являетесь вы: вы отвечаете за законные основания обработки и получение согласий.",
        "Мы обрабатываем данные ваших клиентов только по вашему поручению и только для работы сервиса — подробнее в Политике конфиденциальности.",
        "Список клиентов можно выгрузить в любой момент. После закрытия аккаунта мы удаляем данные в разумный срок, если закон не требует их хранить.",
      ] },
      { h: "5. Оплаты в пользу зала", p: [
        "Онлайн-оплаты клиентов поступают напрямую на счёт зала у подключённого платёжного сервиса (например, ЮKassa). core. не является стороной этих платежей и не держит ваши деньги.",
      ] },
      { h: "6. Допустимое использование", p: [
        "Нельзя использовать core. для нарушения закона, рассылки спама, доступа к данным других клиентов сервиса или вмешательства в его работу.",
      ] },
      { h: "7. Доступность и ответственность", p: [
        "Мы стараемся, чтобы core. работал стабильно и безопасно, но не гарантируем бесперебойную работу. В пределах, допустимых законом, наша ответственность ограничена суммой, оплаченной вами за 12 месяцев до претензии.",
      ] },
      { h: "8. Прекращение", p: [
        "Вы можете перестать пользоваться core. в любой момент. Мы можем приостановить аккаунт, нарушающий эти условия, по возможности предупредив заранее.",
      ] },
      { h: "9. Контакты", p: [contact] },
    ],
  },
};

export const PRIVACY: Record<"ru" | "en", LegalDoc> = {
  en: {
    title: "Privacy Policy",
    intro: "This policy explains what personal data core. processes, why, and what rights people have. It applies to gym owners and staff, gym members, and visitors to our website.",
    sections: [
      { h: "1. Who we are", p: [
        `${COMPANY.legalName} operates core. For gym staff accounts we are the controller. For gym members' data, the gym is the controller and we act as its processor.`,
      ] },
      { h: "2. Data we process", p: [
        "Gym staff: name, email, role, login and activity log.",
        "Gym members (on behalf of the gym): name, phone, optional email, date of birth and gender, memberships, visits, bookings, payments, notes, and consents to data processing and marketing.",
        "App users: phone number used to sign in, device identifier and push token, and a secret used to generate the QR pass on the device.",
        "Payment card data is processed by the payment provider; core. never sees full card numbers.",
      ] },
      { h: "3. Why we process it", p: [
        "To provide the service: manage memberships, check members in, run the schedule, take payments, and show reports.",
        "To send service messages and, only with consent, marketing messages from the gym.",
        "To keep the service secure, prevent fraud and meet legal obligations.",
      ] },
      { h: "4. Where data is stored", p: [
        "Russia: personal data of Russian gyms and their members is stored and processed on servers located in the Russian Federation, in line with Federal Law No. 152-FZ “On Personal Data”.",
        "United Arab Emirates: data of UAE gyms is processed in line with Federal Decree-Law No. 45 of 2021 on the Protection of Personal Data. [Storage location for UAE customers]",
      ] },
      { h: "5. Sharing", p: [
        "We share data only with providers needed to run the service (hosting, SMS, push notifications, payment providers), under contracts that protect it. We do not sell personal data.",
      ] },
      { h: "6. Retention", p: [
        "We keep data while the gym uses core. When a gym deletes a member on request, their personal details are anonymised; payment records are kept as required for accounting.",
      ] },
      { h: "7. Your rights", p: [
        "You can ask for access to, correction or deletion of your data and withdraw consent at any time. Gym members should contact their gym first; we will help the gym respond.",
      ] },
      { h: "8. Security", p: [
        "Data is protected by access controls that separate each gym's data, encrypted connections, and encrypted storage of payment provider keys.",
      ] },
      { h: "9. Contact", p: [contact] },
    ],
  },
  ru: {
    title: "Политика конфиденциальности",
    intro: "Эта политика объясняет, какие персональные данные обрабатывает core., зачем и какие права есть у людей. Она касается владельцев и сотрудников залов, клиентов залов и посетителей нашего сайта.",
    sections: [
      { h: "1. Кто мы", p: [
        `Сервис core. предоставляет ${COMPANY.legalName}. Для аккаунтов сотрудников залов мы — оператор данных. Для данных клиентов зала оператором является зал, а мы обрабатываем их по его поручению.`,
      ] },
      { h: "2. Какие данные мы обрабатываем", p: [
        "Сотрудники залов: имя, email, роль, данные входа и журнал действий.",
        "Клиенты залов (по поручению зала): ФИО, телефон, при желании email, дата рождения и пол, абонементы, визиты, записи, оплаты, заметки, согласия на обработку данных и рассылки.",
        "Пользователи приложения: номер телефона для входа, идентификатор устройства и токен уведомлений, секрет для формирования QR-пропуска на устройстве.",
        "Данные банковских карт обрабатывает платёжный сервис; полные номера карт core. не видит.",
      ] },
      { h: "3. Зачем", p: [
        "Чтобы сервис работал: вести абонементы, отмечать визиты, вести расписание, принимать оплаты и показывать отчёты.",
        "Чтобы отправлять служебные сообщения и — только с согласия — рекламные сообщения от зала.",
        "Чтобы защищать сервис, предотвращать мошенничество и выполнять требования закона.",
      ] },
      { h: "4. Где хранятся данные", p: [
        "Россия: персональные данные российских залов и их клиентов хранятся и обрабатываются на серверах в Российской Федерации в соответствии с Федеральным законом № 152-ФЗ «О персональных данных».",
        "ОАЭ: данные залов из ОАЭ обрабатываются в соответствии с Федеральным декрет-законом № 45 от 2021 года о защите персональных данных. [Место хранения для клиентов из ОАЭ]",
      ] },
      { h: "5. Передача третьим лицам", p: [
        "Мы передаём данные только сервисам, без которых core. не работает (хостинг, SMS, push-уведомления, платёжные сервисы), по договорам, которые их защищают. Мы не продаём персональные данные.",
      ] },
      { h: "6. Сроки хранения", p: [
        "Мы храним данные, пока зал пользуется core. Если зал удаляет клиента по его запросу, персональные данные обезличиваются; записи об оплатах сохраняются для бухгалтерии в сроки, установленные законом.",
      ] },
      { h: "7. Ваши права", p: [
        "Вы можете запросить доступ к своим данным, их исправление или удаление и отозвать согласие в любой момент. Клиентам залов лучше сначала обратиться в свой зал — мы поможем ему ответить.",
      ] },
      { h: "8. Безопасность", p: [
        "Данные каждого зала изолированы правами доступа, соединения шифруются, ключи платёжных сервисов хранятся в зашифрованном виде.",
      ] },
      { h: "9. Контакты", p: [contact] },
    ],
  },
};
