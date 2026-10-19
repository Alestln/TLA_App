# Лекция 5. Основы моделирования распределённых систем с помощью TLA+
## (Формирование системного мышления, синтаксис TLA+ и верификация в TLC)

**Дисциплина:** Программирование и защита распределённых и параллельных вычислений  
**Целевая аудитория:** 1 курс магистратуры (Кибербезопасность)  
**Продолжительность:** 1.5 часа (90 минут)  
**Формат:** Интерактивная лекция + практический Live-Demo с разбором 5 сквозных примеров (в каждом: *ошибка $\to$ поиск бага в TLC $\to$ исправление $\to$ доказательство безопасности*).

---

## 🧭 НАВИГАЦИЯ ПО ЗАНЯТИЮ

```text
00:00 ─── 00:15 [15 мин]  БЛОК 1. Зачем безопаснику TLA+? Ограничения тестов и мышление состояниями
00:15 ─── 00:25 [10 мин]  БЛОК 2. Архитектура TLA+, запуск и подробный разбор скрипта run_tlc.ps1
00:25 ─── 00:35 [10 мин]  БЛОК 3. Как мыслить и писать TLA+: «Фреймворк 4 вопросов» и правила синтаксиса
00:35 ─── 00:45 [10 мин]  ПРИМЕР 1. Часы (Ex1_Clock): переменная, штрих ('), инвариант и поломка
00:45 ─── 00:55 [10 мин]  ПРИМЕР 2. Светофор (Ex2_TrafficLight): две переменные, guards и предотвращение аварии
00:55 ─── 01:05 [10 мин]  ПРИМЕР 3. Банкомат (Ex3_BankAtm): двойное списание (TOCTOU) и баланс -60 грн
01:05 ─── 01:15 [10 мин]  ПРИМЕР 4. Параллельный инкремент (Ex4_CounterIncrement): регистры CPU и потеря обновлений
01:15 ─── 01:25 [10 мин]  ПРИМЕР 5. Одноразовый токен / Ваучер (Ex5_OneTimeToken): защита API от Replay/Race атак
01:25 ─── 01:30 [05 мин]  БЛОК 4. Итоги, чек-лист студента и подготовка к Лабораторной работе №3
```

---

# БЛОК 1. Зачем безопаснику TLA+? (15 минут)

### 1.1. В каких ситуациях программисту нужен TLA+? (Критерии и триггеры)

> **Главный вопрос студента:**  
> *«Я пишу бэкенд на C#, Python или Go. Зачем мне тратить время на математическую спецификацию TLA+, если я могу просто сесть и сразу писать код с тестами?»*

#### Золотое правило Лесли Лэмпорта:
> *«Если вы не можете точно описать, КАК должна работать ваша система на уровне логики, вы гарантированно напишете код с ошибками, которые не поймает ни один компилятор».*

---

#### 🚨 4 КРИТЕРИЯ-ТРИГГЕРА: «Когда программист ОБЯЗАН открыть TLA+»:

Нарисуйте на доске чек-лист архитектора безопасности:

```text
               КОГДА НУЖЕН TLA+? (ЧЕК-ЛИСТ АРХИТЕКТОРА)
  
  [1] ЕСТЬ КОНКУРЕНТНЫЙ ДОСТУП К ОБЩЕМУ РЕСУРСУ? (Threads, Lock-free, CAS)
  [2] ЕСТЬ РАСПРЕДЕЛЁННОСТЬ И СЕТЬ?             (Микросервисы, очереди, 2PC, Saga)
  [3] ЕСТЬ СЛОЖНЫЙ АВТОМАТ СОСТОЯНИЙ?           (Жизненный цикл токена, заказа, сессии)
  [4] ЦЕНА ОШИБКИ КРИТИЧЕСКИ ВЫСОКА?            (Деньги, авторизация, доступ, DoS)
```

Разберите каждый триггер на пальцах с конкретными примерами:

#### Триггер 1: Многопоточность и разделяемое состояние (Concurrency & Shared State)
* **Ситуация:** Два и более потока внутри одного приложения читают и меняют одну и ту же область памяти или ресурс.
* **Почему тесты бессильны:** Разработчик пишет `Interlocked.Increment` или ставит `lock`, полагая, что защитил код. Но если проверка условия и действие разделены хоть на 1 наносекунду — возникает **TOCTOU (Time-of-Check to Time-of-Use)**. Планировщик ОС в 99.999% случаев выполнит код нормально, а на миллионный раз переключит контекст в зазоре между проверкой и записью.
* **Примеры:** Сетевые шлюзы с лимитами соединений, пулы потоков, пулы соединений к БД, буферы сообщений RingBuffer.

#### Триггер 2: Распределённость, асинхронность и сеть (Distributed Systems & Network)
* **Ситуация:** Система состоит из нескольких узлов (микросервисов, баз данных, брокеров Kafka/RabbitMQ).
* **Специфика распределённых систем:**
  1. Сообщения по сети приходят **не по порядку** (пакет 2 обогнал пакет 1).
  2. Сообщения **дублируются** (сеть моргнула, сработал Retry).
  3. Сообщения **теряются** (Dropped packets).
  4. Узлы падают в самый неподходящий момент (*Crash-Stop failure*).
* **Когда писать TLA+:** Протоколы двухфазной фиксации (**2PC**), распределённые саги (**Saga Choreography**), выбор лидера (**Leader Election / Raft / Paxos**), репликация баз данных. Ни один интеграционный стенд в Docker не способен сымитировать все комбинации сетевых партиций (Split-Brain). TLA+ перебирает их автоматически!

#### Триггер 3: Критический жизненный цикл сущности (State Machine Flaws)
* **Ситуация:** У объекта есть сложный набор статусов:  
  `Created -> Pending -> Authorized -> Captured -> Refunded`.
* **Вектор атаки:** Злоумышленник пытается нарушить логику переходов:
  * Можно ли вызвать `Refund` (возврат средств) дважды параллельно?
  * Можно ли перевести платёж в `Captured`, минуя проверку `Authorized`?
  * Можно ли использовать одноразовый токен (OTP, промокод, JWT jti, ссылка сброса пароля) дважды, отправив два HTTP-запроса в одну миллисекунду?
* **Роль TLA+:** Мы описываем все переходы статусов и задаем инвариант безопасности: *«Деньги возвращены ровно 1 раз»*. TLC моментально находит путь обхода, если такой существует.

#### Триггер 4: Высокая цена ошибки (High-Stakes Software)
* Если ваш сервис упал в интернет-магазине с одеждой — покупатель обновит страницу.
* Но если уязвимость возникла в:
  * **Банковском процессинге** (двойное списание, уход баланса в минус);
  * **Криптографическом протоколе / Смарт-контракте** (кража ликвидности — знаменитый The DAO Hack на $60 млн случился именно из-за уязвимости повторного входа Reentrancy, которую TLA+ выявляет на базовой модели);
  * **Шлюзе авторизации / Zero-Trust API** (обход политик доступа);
  * **Медицинском и промышленном софте** (Therac-25 — радиационный аппарат убил людей именно из-за состояния гонки при вводе команд оператором!).

---

#### ⚖️ СРАВНИТЕЛЬНЫЙ КВАДРАНТ: КОГДА TLA+ НУЖЕН, А КОГДА ИЗБЫТОЧЕН

Студент должен четко понимать границы применимости инструмента:

| Задача разработки | Нужен ли TLA+? | Почему? |
| :--- | :---: | :--- |
| **Обычный CRUD (Create/Read/Update/Delete)** | ❌ **НЕТ** | Логика линейна, за целостность отвечает ACID базы данных. Достаточно Unit-тестов. |
| **Вёрстка UI, парсинг JSON, CSS, DTO** | ❌ **НЕТ** | Здесь нет параллельных состояний и недетерминизма. |
| **Сложные вычисления (ML-модель, физика)** | ❌ **НЕТ** | TLA+ не оптимизирован для вычисления сложных численных матриц. |
| **Конкурентный доступ к общему балансу / квоте** |  **ДА!** | Высокий риск Race Condition (TOCTOU), тесты пропустят гонку. |
| **Протокол синхронизации или консенсуса** |  **ДА!** | Недетерминизм сети невозможно полностью проверить тестами. |
| **Асинхронное взаимодействие микросервисов** |  **ДА!** | Гарантия отсутствия взаимных блокировок (Deadlocks) и потери сообщений. |
| **Протокол аутентификации и управление ключами** |  **ДА!** | Доказательство невозможности обхода шагов верификации. |

> **Формула запоминания для студента:**  
> *«TLA+ нужен там, где есть **несколько независимых участников** (потоков, серверов, клиентов), которые взаимодействуют через **общее состояние** (память, сеть, диск), и цена логической ошибки высока».*

---

### 1.2. Фундаментальный кризис эмпирического тестирования
Объясняем студентам математическую причину:
1. **Тест проверяет одну случайную трассу.** Планировщик ОС переключает потоки недетерминированно. Сетевые пакеты приходят с непредсказуемой задержкой.
2. **Комбинаторный взрыв:** Если 2 потока выполняют по 3 операции, существует 20 вариантов их взаимного чередования. Если 10 потоков выполняют по 5 шагов — количество вариантов превышает $10^{38}$.
3. **Разница между QA и Хакером:**
   * Для QA-инженера баг, случившийся 1 раз на 1 000 000 запусков — это «невоспроизводимый флакающий тест».
   * Для хакера этот 1 случай из миллиона — **готовый эксплойт (Zero-Day)**. Злоумышленник скриптом ударит в API десятками тысяч параллельных запросов, искусственно создаст нужное чередование и опустошит баланс.

### 1.3. Где в реальном мире используется TLA+?
* **Amazon Web Services (AWS):** Ядро Amazon S3, DynamoDB и EBS спроектированы в TLA+. Инженеры AWS официально опубликовали статьи о том, что TLA+ помогла найти критические уязвимости потери данных, требовавшие цепочки из 35 специфических отказов сети и переключений потоков, которые физически невозможно было покрыть тестами.
* **Microsoft Azure:** Протоколы консенсуса и репликации Azure Cosmos DB.
* **Криптография и Финтех:** Доказательство невозможности атаки двойной траты (Double Spending) и обхода верификации смарт-контрактов.

---

# БЛОК 2. Инструментарий и анатомия PowerShell-скрипта (10 минут)

### 2.1. Что студентам установить дома
Выведите на экран:
1. **Java Runtime (JRE/JDK) версии 11 или выше** (`java -version`).
2. Любой удобный редактор:
   * **TLA+ Toolbox** (официальная IDE): [lamport.azurewebsites.net/tla/toolbox.html](https://lamport.azurewebsites.net/tla/toolbox.html).
   * **VS Code** с расширением **"TLA+"** (автор: *Markus Alexander Kuppe*).
   * **JetBrains Rider / Терминал** с файлом `tla2tools.jar` (как в нашем репозитории).

---

### 2.2. Подробный разбор скрипта запуска `run_tlc.ps1`
Разберите со студентами файл [run_tlc.ps1](file:///c:/Users/Alestln/RiderProjects/TLA_App/TLA_App/tla/run_tlc.ps1). Студенты должны понимать, как устроен запуск model checker'а под капотом:

```powershell
param (
    [string]$Spec = "Ex1_Clock",  # Имя спецификации (без расширения .tla)
    [switch]$Full                 # Флаг -Full: показать полный сырой вывод TLC
)
```
* **Строка 1–4:** Объявляем параметры скрипта. `$Spec` принимает имя файла, а флаг `-Full` позволяет переключиться на детальный вывод JVM при отладке.

```powershell
$jarPath = Join-Path $PSScriptRoot "tla2tools.jar"
if (-not (Test-Path $jarPath)) {
    # Автоматическое скачивание официального релиза tla2tools.jar с GitHub
    Invoke-WebRequest -Uri "https://github.com/tlaplus/tlaplus/releases/download/v1.8.0/tla2tools.jar" -OutFile $jarPath
}
```
* **Строка 6–19:** Если в папке нет исполняемого архива TLA+ (`tla2tools.jar`), скрипт сам безопасно скачивает его по HTTPS.

```powershell
$tlcArgs = @(
    "-XX:+UseParallelGC",   # Включает параллельный сборщик мусора (убирает предупреждение TLC)
    "-cp", $jarPath,        # Добавляет tla2tools.jar в classpath Java
    "tlc2.TLC",             # Имя главного исполняемого класса верификатора
    "-nowarning",           # Отключает предупреждения линтера о неиспользуемых операторах
    "-noGenerateSpecTE",    # Запрещает создавать мусорные файлы трасс (*_TTrace_*.tla)
    "-cleanup",             # Автоматически удаляет рабочую папку 'states' после проверки
    "-config", $cfgFile,    # Путь к файлу конфигурации модели (.cfg)
    $tlaFile                # Путь к файлу математической спецификации (.tla)
)
```
* **Строка 28–34:** Ключевые флаги запуска TLC. Мы отключаем генерацию мусорных файлов на диске и подавляем шум.

```powershell
# Регулярное выражение для фильтрации служебного спама компилятора:
$noise = '^(TLC2 Version|Running |Parsing file|Semantic processing|Linting of module|...)'

& java @tlcArgs 2>&1 | Where-Object { $_ -notmatch $noise } | ForEach-Object {
    if     ($_ -match 'violated|^Error|Deadlock') { Write-Host $_ -ForegroundColor Red }
    elseif ($_ -match 'No error has been found')  { Write-Host $_ -ForegroundColor Green }
    elseif ($_ -match '^State \d+:')              { Write-Host $_ -ForegroundColor Yellow }
    else                                          { Write-Host $_ }
}
```
* **Строка 43–52:** Конвейер фильтрации: отсекает 50 строк служебного вывода парсера и парсит результат:
  * 🔴 **Красный цвет:** Нарушение инварианта безопасности или взаимная блокировка (*Deadlock*).
  * 🟡 **Желтый цвет:** Номера шагов контрпримера (`State 1`, `State 2`...).
  * 🟢 **Зеленый цвет:** Успешное завершение верификации (0 ошибок).

---

# БЛОК 3. Как мыслить и писать TLA+: «Фреймворк 4 вопросов» (10 минут)

Студент открывает пустой файл. Что писать? Дайте аудитории **четкий алгоритм**:

```text
               АЛГОРИТМ ДЕКОМПОЗИЦИИ ЛЮБОЙ СИСТЕМЫ В TLA+:
  
  1. КАКИМИ ПЕРЕМЕННЫМИ ОПИСЫВАЕТСЯ МИР?  ──>  VARIABLES
  2. С ЧЕГО МИР НАЧИНАЕТСЯ?               ──>  Init
  3. ЧТО МОЖЕТ ПРОИЗОЙТИ В СИСТЕМЕ?       ──>  Next (Действие_1 \/ Действие_2)
  4. ЧТО НИКОГДА НЕ ДОЛЖНО СЛУЧИТЬСЯ?     ──>  INVARIANT (Инвариант безопасности)
```

### Главные синтаксические правила TLA+:
1. **`==` против `=`:**
   * `==` — это **определение** («называем формулу этим именем»). Как `void MyMethod()`.
   * `=` — это **сравнение на равенство** (как `==` в C#). Никакого присваивания нет!
2. **Штрих-нотация (`x'`):**
   * $x$ — значение переменной **сейчас** (в текущем состоянии).
   * $x'$ — значение переменной **в следующем состоянии** (после перехода).
   * Запись `x' = x + 1` означает: *«в новом состоянии значение x на 1 больше старого»*.
3. **Охранные условия (Guards):**
   * Условия, когда действие разрешено, пишутся **без штриха в начале формулы**:  
     `balance >= 80 /\ balance' = balance - 80`.  
     Если `balance < 80`, действие заблокировано математически.
4. **Обязательное правило `UNCHANGED`:**
   * В C# переменная сохраняет память автоматически. В математике, если вы не сказали, чему равен $y'$, он может стать чем угодно. Поэтому в действии, меняющем $x$, обязательно пишем: `UNCHANGED y`.
5. **Списки `/\` и `\/` вместо фигурных скобок:**
   * `/\` — это логическое И ($\land$). Все пункты списка должны быть истинны.
   * `\/` — это логическое ИЛИ ($\lor$). Система может выбрать любую из веток.

---

# ПРИМЕР 1. Настенные часы (`Ex1_Clock`) (10 минут)
> **Концепт:** Базовый синтаксис, переменная, штрих (`'`), инвариант диапазона, первый запуск TLC.  
> **Ошибочный вариант:** [Ex1_Clock_Buggy.tla](file:///c:/Users/Alestln/RiderProjects/TLA_App/TLA_App/tla/Ex1_Clock_Buggy.tla) и [Ex1_Clock_Buggy.cfg](file:///c:/Users/Alestln/RiderProjects/TLA_App/TLA_App/tla/Ex1_Clock_Buggy.cfg)  
> **Исправленный вариант:** [Ex1_Clock_Fixed.tla](file:///c:/Users/Alestln/RiderProjects/TLA_App/TLA_App/tla/Ex1_Clock_Fixed.tla) и [Ex1_Clock_Fixed.cfg](file:///c:/Users/Alestln/RiderProjects/TLA_App/TLA_App/tla/Ex1_Clock_Fixed.cfg)

### 1. Декомпозиция по 4 вопросам:
* **Вопрос 1 (Переменные):** `VARIABLE hour` (стрелка часов).
* **Вопрос 2 (Init):** `Init == hour = 1` (начинаем с 1 часа).
* **Вопрос 4 (Инвариант):** `TypeOK == hour \in 1..12` (стрелка обязана быть в диапазоне от 1 до 12).
* **Вопрос 3 (Next) в `Ex1_Clock_Buggy.tla`:**
  ```tla
  Next == hour' = hour + 1
  ```

### 2. Запуск TLC для ошибочной модели:
```powershell
powershell -ExecutionPolicy Bypass -File .\tla\run_tlc.ps1 -Spec Ex1_Clock_Buggy
```
**Вывод TLC (Контрпример):**
```text
Error: Invariant TypeOK is violated.
State 1:  hour = 1
State 2:  hour = 2
...
State 12: hour = 12
State 13: hour = 13  <-- НАРУШЕНИЕ: 13 не входит в диапазон 1..12!
```
*Объясняем студентам:* TLC прошел 13 шагов и мгновенно нашел состояние переполнения.

### 3. Исправление в `Ex1_Clock_Fixed.tla`:
В исправленном файле учитываем цикличность стрелки (после 12 идет 1):
```tla
Next == hour' = IF hour = 12 THEN 1 ELSE hour + 1
```
Запуск проверки:
```powershell
powershell -ExecutionPolicy Bypass -File .\tla\run_tlc.ps1 -Spec Ex1_Clock_Fixed
```
🟢 **`Model checking completed. No error has been found. 12 distinct states found.`**  
*(TLC обошел все 12 делений циферблата и доказал, что стрелка никогда не выйдет за границы).*

---

# ПРИМЕР 2. Светофор на перекрёстке (`Ex2_TrafficLight`) (10 минут)
> **Концепт:** 2 переменные, множества строк `{"red", "green"}`, инвариант безопасности реального мира, понятие Guard.  
> **Ошибочный вариант:** [Ex2_TrafficLight_Buggy.tla](file:///c:/Users/Alestln/RiderProjects/TLA_App/TLA_App/tla/Ex2_TrafficLight_Buggy.tla) и [Ex2_TrafficLight_Buggy.cfg](file:///c:/Users/Alestln/RiderProjects/TLA_App/TLA_App/tla/Ex2_TrafficLight_Buggy.cfg)  
> **Исправленный вариант:** [Ex2_TrafficLight_Fixed.tla](file:///c:/Users/Alestln/RiderProjects/TLA_App/TLA_App/tla/Ex2_TrafficLight_Fixed.tla) и [Ex2_TrafficLight_Fixed.cfg](file:///c:/Users/Alestln/RiderProjects/TLA_App/TLA_App/tla/Ex2_TrafficLight_Fixed.cfg)

### 1. Суть задачи:
Два светофора: `lightNS` (Север-Юг) и `lightEW` (Восток-Запад).  
**Инвариант безопасности (Safety):** Машины не должны врезаться:
```tla
SafetyNoCrash == ~ (lightNS = "green" /\ lightEW = "green")
```

### 2. Ошибочный код (`Ex2_TrafficLight_Buggy.tla`):
```tla
SwitchNS ==
    /\ lightNS' = IF lightNS = "red" THEN "green" ELSE "red"
    /\ UNCHANGED lightEW

SwitchEW ==
    /\ lightEW' = IF lightEW = "red" THEN "green" ELSE "red"
    /\ UNCHANGED lightNS

Next == SwitchNS \/ SwitchEW
```

### 3. Запуск TLC для ошибочной модели:
```powershell
powershell -ExecutionPolicy Bypass -File .\tla\run_tlc.ps1 -Spec Ex2_TrafficLight_Buggy
```
**Вывод TLC:**
```text
Error: Invariant SafetyNoCrash is violated.
State 1: lightNS = "green", lightEW = "red"
State 2: <SwitchEW>
         lightNS = "green", lightEW = "green"  <-- ОБА ЗЕЛЕНЫХ! АВАРИЯ НА ШАГЕ 2!
```

### 4. Исправление в `Ex2_TrafficLight_Fixed.tla` (Guards):
Включить зелёный свет можно ТОЛЬКО если второй светофор УЖЕ красный:
```tla
TurnGreenEW ==
    /\ lightNS = "red"          \* ОХРАННОЕ УСЛОВИЕ (Guard)
    /\ lightEW = "red"
    /\ lightEW' = "green"
    /\ UNCHANGED lightNS
```
Запуск проверки:
```powershell
powershell -ExecutionPolicy Bypass -File .\tla\run_tlc.ps1 -Spec Ex2_TrafficLight_Fixed
```
🟢 **`Model checking completed. No error has been found.`**

---

# ПРИМЕР 3. Банкомат и двойное списание (`Ex3_BankAtm`) (10 минут)
> **Концепт:** Классический TOCTOU (Time-of-Check to Time-of-Use) / Race Condition без C#. Отрицательный баланс.  
> **Ошибочный вариант:** [Ex3_BankAtm_Buggy.tla](file:///c:/Users/Alestln/RiderProjects/TLA_App/TLA_App/tla/Ex3_BankAtm_Buggy.tla) и [Ex3_BankAtm_Buggy.cfg](file:///c:/Users/Alestln/RiderProjects/TLA_App/TLA_App/tla/Ex3_BankAtm_Buggy.cfg)  
> **Исправленный вариант:** [Ex3_BankAtm_Fixed.tla](file:///c:/Users/Alestln/RiderProjects/TLA_App/TLA_App/tla/Ex3_BankAtm_Fixed.tla) и [Ex3_BankAtm_Fixed.cfg](file:///c:/Users/Alestln/RiderProjects/TLA_App/TLA_App/tla/Ex3_BankAtm_Fixed.cfg)

### 1. Сюжет кибератаки:
На счете **100 грн**. Два сообщника в двух банкоматах (`atm1` и `atm2`) **одновременно** запрашивают по 80 грн.  
**Инвариант:** `NoOverdraft == balance >= 0`.

### 2. Ошибочный код (`Ex3_BankAtm_Buggy.tla`):
```tla
Atm1_Check ==
    /\ atm1 = "idle" /\ balance >= 80
    /\ atm1' = "authorized"
    /\ UNCHANGED <<balance, atm2>>  \* Деньги НЕ списаны!

Atm1_Withdraw ==
    /\ atm1 = "authorized"
    /\ balance' = balance - 80
    /\ atm1' = "done"
    /\ UNCHANGED atm2
```

### 3. Запуск TLC для ошибочной модели:
```powershell
powershell -ExecutionPolicy Bypass -File .\tla\run_tlc.ps1 -Spec Ex3_BankAtm_Buggy
```
**Вывод TLC (Контрпример эксплойта):**
```text
State 1: balance = 100, atm1 = "idle",       atm2 = "idle"
State 2: <Atm1_Check>
         balance = 100, atm1 = "authorized", atm2 = "idle"        (ATM 1 одобрил 80 грн)
State 3: <Atm2_Check>
         balance = 100, atm1 = "authorized", atm2 = "authorized"  (ATM 2 ТОЖЕ одобрил 80 грн!)
State 4: <Atm1_Withdraw>
         balance = 20,  atm1 = "done",       atm2 = "authorized"  (ATM 1 выдал 80 грн)
State 5: <Atm2_Withdraw>
         balance = -60, atm1 = "done",       atm2 = "done"        (ATM 2 выдал 80 грн -> БАЛАНС -60!)
Error: Invariant NoOverdraft is violated.
```

### 4. Исправление в `Ex3_BankAtm_Fixed.tla`:
Проверка и списание объединены в **единую атомарную транзакцию** (аналог SQL CAS):
```tla
Atm1_Withdraw ==
    /\ atm1 = "idle"
    /\ IF balance >= 80
       THEN /\ balance' = balance - 80
            /\ atm1' = "done"
       ELSE /\ atm1' = "rejected"
            /\ UNCHANGED balance
    /\ UNCHANGED atm2
```
Запуск проверки:
```powershell
powershell -ExecutionPolicy Bypass -File .\tla\run_tlc.ps1 -Spec Ex3_BankAtm_Fixed
```
🟢 **`Model checking completed. No error has been found.`**

---

# ПРИМЕР 4. Параллельный инкремент (`Ex4_Counter`) (10 минут)
> **Концепт:** Моделирование регистров процессора и машинных команд. Почему `counter++` в C# небезопасен при конкурентности.  
> **Ошибочный вариант:** [Ex4_Counter_Buggy.tla](file:///c:/Users/Alestln/RiderProjects/TLA_App/TLA_App/tla/Ex4_Counter_Buggy.tla) и [Ex4_Counter_Buggy.cfg](file:///c:/Users/Alestln/RiderProjects/TLA_App/TLA_App/tla/Ex4_Counter_Buggy.cfg)  
> **Исправленный вариант:** [Ex4_Counter_Fixed.tla](file:///c:/Users/Alestln/RiderProjects/TLA_App/TLA_App/tla/Ex4_Counter_Fixed.tla) и [Ex4_Counter_Fixed.cfg](file:///c:/Users/Alestln/RiderProjects/TLA_App/TLA_App/tla/Ex4_Counter_Fixed.cfg)

### 1. Как `counter++` устроен внутри процессора:
1. `Read`: поток читает `counter` из RAM в регистр CPU (`t_reg`).
2. `Write`: поток прибавляет 1 к регистру и пишет обратно в RAM.

### 2. Ошибочный код (`Ex4_Counter_Buggy.tla`):
```tla
T1_Read ==
    /\ t1_pc = "idle"
    /\ t1_reg' = counter
    /\ t1_pc' = "read"
    /\ UNCHANGED <<counter, t2_pc, t2_reg>>

T1_Write ==
    /\ t1_pc = "read"
    /\ counter' = t1_reg + 1
    /\ t1_pc' = "done"
    /\ UNCHANGED <<t1_reg, t2_pc, t2_reg>>
```
**Инвариант:** Когда оба потока закончили, счетчик обязан быть равен 2:
```tla
CorrectSum == (t1_pc = "done" /\ t2_pc = "done") => (counter = 2)
```

### 3. Запуск TLC для ошибочной модели:
```powershell
powershell -ExecutionPolicy Bypass -File .\tla\run_tlc.ps1 -Spec Ex4_Counter_Buggy
```
**Вывод TLC:**
```text
State 1: counter = 0, t1_reg = 0, t2_reg = 0
State 2: <T1_Read>  t1 прочитал 0 в регистр t1_reg
State 3: <T2_Read>  t2 ТОЖЕ прочитал 0 в регистр t2_reg!
State 4: <T1_Write> t1 записал (0 + 1) = 1 в counter
State 5: <T2_Write> t2 записал (0 + 1) = 1 в counter (ПЕРЕЗАПИСАЛ!)
Error: Invariant CorrectSum is violated. (counter = 1 вместо 2!)
```

### 4. Исправление в `Ex4_Counter_Fixed.tla`:
Атомарный инкремент (аналог `Interlocked.Increment` в C# или `std::atomic::fetch_add` в C++):
```tla
T1_Inc ==
    /\ ~t1_done
    /\ counter' = counter + 1
    /\ t1_done' = TRUE
    /\ UNCHANGED t2_done
```
Запуск проверки:
```powershell
powershell -ExecutionPolicy Bypass -File .\tla\run_tlc.ps1 -Spec Ex4_Counter_Fixed
```
🟢 **`Model checking completed. No error has been found.`**

---

# ПРИМЕР 5. Практический кейс: Одноразовый токен (`Ex5_OneTimeToken`) (10 минут)
> **Концепт:** Реальный вектор атаки на Web API: повторное погашение промокода / ваучера / ссылки сброса пароля (Double Redeem / Replay Attack).  
> **Ошибочный вариант:** [Ex5_OneTimeToken_Buggy.tla](file:///c:/Users/Alestln/RiderProjects/TLA_App/TLA_App/tla/Ex5_OneTimeToken_Buggy.tla) и [Ex5_OneTimeToken_Buggy.cfg](file:///c:/Users/Alestln/RiderProjects/TLA_App/TLA_App/tla/Ex5_OneTimeToken_Buggy.cfg)  
> **Исправленный вариант:** [Ex5_OneTimeToken_Fixed.tla](file:///c:/Users/Alestln/RiderProjects/TLA_App/TLA_App/tla/Ex5_OneTimeToken_Fixed.tla) и [Ex5_OneTimeToken_Fixed.cfg](file:///c:/Users/Alestln/RiderProjects/TLA_App/TLA_App/tla/Ex5_OneTimeToken_Fixed.cfg)

### 1. Сюжет уязвимости:
Пользователь активирует промокод на 500 бонусов. Злоумышленник посылает в API два одновременных HTTP-запроса (`req1` и `req2`).  
**Инвариант безопасности:** По одному промокоду нельзя получить больше 500 бонусов:
```tla
MaxOneRedemption == user_balance <= 500
```

### 2. Ошибочный код (`Ex5_OneTimeToken_Buggy.tla`):
Проверка валидности токена и его погашение в базе разделены:
```tla
Req1_Check ==
    /\ req1_state = "idle"
    /\ IF token_status = "UNUSED"
       THEN req1_state' = "authorized"
       ELSE req1_state' = "rejected"
    /\ UNCHANGED <<token_status, user_balance, req2_state>>

Req1_Redeem ==
    /\ req1_state = "authorized"
    /\ user_balance' = user_balance + 500
    /\ token_status' = "USED"
    /\ req1_state' = "success"
    /\ UNCHANGED req2_state
```

### 3. Запуск TLC для ошибочной модели:
```powershell
powershell -ExecutionPolicy Bypass -File .\tla\run_tlc.ps1 -Spec Ex5_OneTimeToken_Buggy
```
**Вывод TLC:**
```text
State 1: user_balance = 0,    token_status = "UNUSED"
State 2: <Req1_Check>  req1 проверил токен -> "authorized"
State 3: <Req2_Check>  req2 проверил токен -> "authorized" (ТОЖЕ одобрено!)
State 4: <Req1_Redeem> req1 начислил 500 бонусов -> user_balance = 500,  token_status = "USED"
State 5: <Req2_Redeem> req2 начислил 500 бонусов -> user_balance = 1000! (ВЗЛОМ API!)
Error: Invariant MaxOneRedemption is violated.
```

### 4. Исправление в `Ex5_OneTimeToken_Fixed.tla`:
Атомарный Compare-And-Swap (CAS) в базе данных:  
`UPDATE vouchers SET status = 'USED' WHERE id = 'X' AND status = 'UNUSED'`
```tla
Req1_Redeem ==
    /\ req1_state = "idle"
    /\ IF token_status = "UNUSED"
       THEN /\ token_status' = "USED"
            /\ user_balance' = user_balance + 500
            /\ req1_state' = "success"
       ELSE /\ req1_state' = "rejected"
            /\ UNCHANGED <<token_status, user_balance>>
    /\ UNCHANGED req2_state
```
Запуск проверки:
```powershell
powershell -ExecutionPolicy Bypass -File .\tla\run_tlc.ps1 -Spec Ex5_OneTimeToken_Fixed
```
🟢 **`Model checking completed. No error has been found.`**

---

# БЛОК 4. Итоги занятия и Лабораторная работа №3 (5 минут)

### Золотые правила для студента на лабораторных работах:
1. **Любая распределённая система — это граф состояний.** Не думайте строчками C#, думайте тем, какие переменные существуют в системе.
2. **Атомарность в TLA+ = Одно действие.** Если между проверкой и изменением есть хоть наносекунда задержки в реальности — моделируйте это как ДВА разных действия TLA+. TLC покажет вам, как в этот зазор вклинится атакующий.
3. **Анонс Лекции 6 и Лабораторной №3:**
   * На следующей лекции мы научимся масштабировать модели на $N$ потоков с помощью кванторов $\forall$ (`\A`) и $\exists$ (`\E`) и разберем классические алгоритмы взаимного исключения (Деккера и Петерсона).
