using System.Diagnostics;

namespace TLA_App.Lecture6;

/// <summary>
/// Классический deadlock двух замков на примере банковских переводов.
/// TLA+: tla/L6_Ex4_Transfer_Deadlock.tla и tla/L6_Ex4_Transfer_Fixed.tla
/// </summary>
public static class TransferDeadlockDemo
{
    public sealed class Account
    {
        public Account(int id, decimal balance) { Id = id; Balance = balance; }
        public int Id { get; }
        public decimal Balance { get; set; }
    }

    private static readonly Stopwatch Clock = new();

    /// <param name="orderedLocks">false = замки берутся «как в коде» (from, to); true = по возрастанию Id.</param>
    public static void Run(bool orderedLocks)
    {
        Console.ForegroundColor = ConsoleColor.Cyan;
        Console.WriteLine(orderedLocks
            ? "=== Перевод денег: замки берутся по возрастанию номера счёта (ИСПРАВЛЕНО) ==="
            : "=== Перевод денег: lock(from) -> lock(to) (DEADLOCK) ===");
        Console.ResetColor();

        var acc1 = new Account(1, 1000m);
        var acc2 = new Account(2, 1000m);
        Clock.Restart();

        var t1 = new Thread(() => Transfer("t1", acc1, acc2, 100m, orderedLocks)) { IsBackground = true };
        var t2 = new Thread(() => Transfer("t2", acc2, acc1, 50m, orderedLocks)) { IsBackground = true };
        t1.Start();
        t2.Start();

        var timeout = TimeSpan.FromSeconds(3);
        bool finished = t1.Join(timeout) & t2.Join(timeout);

        if (!finished)
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine($"\nDEADLOCK: потоки ждут друг друга уже {timeout.TotalSeconds:0} с и никогда не дождутся.");
            Console.WriteLine("t1 держит счёт №1 и ждёт №2, t2 держит счёт №2 и ждёт №1 (циклическое ожидание).");
            Console.WriteLine("Потоки фоновые: они останутся висеть, пока не закроется программа. В продакшене — до перезапуска сервиса.");
            Console.ResetColor();
        }
        else
        {
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine($"\nОба перевода выполнены. Счёт №1 = {acc1.Balance}, счёт №2 = {acc2.Balance}, сумма = {acc1.Balance + acc2.Balance} (деньги не потерялись).");
            Console.ResetColor();
        }
        Console.WriteLine();
    }

    private static void Transfer(string name, Account from, Account to, decimal amount, bool orderedLocks)
    {
        // ИСПРАВЛЕНИЕ = одна строка: глобальный порядок захвата замков (TLA+: First/Second через Min/Max)
        var (first, second) = orderedLocks && from.Id > to.Id ? (to, from) : (from, to);

        Log(name, $"жду замок счёта №{first.Id}");
        lock (first)
        {
            Log(name, $"захватил счёт №{first.Id}");          // TLA+: TakeFirst
            Thread.Sleep(100);                                 // проверка лимитов, антифрод, журнал...
            Log(name, $"жду замок счёта №{second.Id}");
            lock (second)
            {
                Log(name, $"захватил счёт №{second.Id}");     // TLA+: TakeSecond
                from.Balance -= amount;
                to.Balance += amount;
            }
        }
        Log(name, $"перевод {amount} со счёта №{from.Id} на №{to.Id} выполнен, замки отпущены"); // TLA+: Release
    }

    private static readonly object LogGate = new();

    private static void Log(string thread, string message)
    {
        lock (LogGate)
        {
            Console.ForegroundColor = thread == "t1" ? ConsoleColor.Yellow : ConsoleColor.Magenta;
            Console.WriteLine($"[{Clock.ElapsedMilliseconds,4} мс] [{thread}] {message}");
            Console.ResetColor();
        }
    }
}
