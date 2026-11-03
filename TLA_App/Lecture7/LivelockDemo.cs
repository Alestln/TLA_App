using System.Diagnostics;

namespace TLA_App.Lecture7;

/// <summary>Замок ровно для двух потоков (me = 0 или 1).</summary>
public interface ITwoThreadLock
{
    string Name { get; }
    void Lock(int me, ref long backoffs, ref long longestStreak);
    void Unlock(int me);
}

/// <summary>
/// «Вежливые» потоки (TLA+: L7_Ex3_Livelock_Polite):
/// увидел, что сосед тоже хочет, — опусти флаг, подожди, подними снова.
/// Deadlock-а нет, но потоки могут бесконечно уступать друг другу (livelock).
/// </summary>
public sealed class PoliteLock : ITwoThreadLock
{
    private readonly int[] _flag = new int[2];
    public string Name => "«Вежливые» потоки: увидел соседа -> опустил флаг -> попробовал снова";

    public void Lock(int me, ref long backoffs, ref long longestStreak)
    {
        int other = 1 - me;
        Volatile.Write(ref _flag[me], 1);                     // SetFlag
        Interlocked.MemoryBarrier();
        long streak = 0;
        while (Volatile.Read(ref _flag[other]) == 1)          // CheckBusy
        {
            Volatile.Write(ref _flag[me], 0);                 // Backoff: вежливо уступаю
            backoffs++;
            streak++;
            Thread.SpinWait(50);                              //          и немного жду
            Volatile.Write(ref _flag[me], 1);                 // Retry: снова хочу
            Interlocked.MemoryBarrier();
        }
        if (streak > longestStreak) longestStreak = streak;   // CheckFree -> вхожу в КС
    }

    public void Unlock(int me) => Volatile.Write(ref _flag[me], 0);
}

/// <summary>
/// Алгоритм Петерсона (TLA+: L7_Ex3_Peterson_Liveness). Переменная turn — арбитр:
/// при конфликте всегда есть ровно один победитель, поэтому вечной вежливости нет.
/// </summary>
public sealed class PetersonLock : ITwoThreadLock
{
    private readonly int[] _flag = new int[2];
    private int _turn;
    public string Name => "Петерсон: flag + turn (арбитр)";

    public void Lock(int me, ref long backoffs, ref long longestStreak)
    {
        int other = 1 - me;
        Volatile.Write(ref _flag[me], 1);
        Volatile.Write(ref _turn, other);
        Interlocked.MemoryBarrier();                          // барьер — см. лекцию 6
        var spinner = new SpinWait();
        while (Volatile.Read(ref _flag[other]) == 1 && Volatile.Read(ref _turn) == other)
            spinner.SpinOnce(sleep1Threshold: -1);            // жду, но НЕ уступаю свой флаг
    }

    public void Unlock(int me) => Volatile.Write(ref _flag[me], 0);
}

public static class LivelockDemo
{
    public static void Run(ITwoThreadLock theLock, TimeSpan duration)
    {
        Console.ForegroundColor = ConsoleColor.Cyan;
        Console.WriteLine($"=== {theLock.Name} ===");
        Console.ResetColor();
        Console.WriteLine($"Два потока, {duration.TotalSeconds:0} с, оба без пауз хотят в критическую секцию.\n");

        var entries = new long[2];
        var backoffs = new long[2];
        var streaks = new long[2];
        long inside = 0, violations = 0;
        bool stop = false;
        using var startGate = new ManualResetEventSlim(false);

        var threads = new Thread[2];
        for (int i = 0; i < 2; i++)
        {
            int me = i;
            threads[i] = new Thread(() =>
            {
                long myBackoffs = 0, myStreak = 0, myEntries = 0;
                startGate.Wait();
                while (!Volatile.Read(ref stop))
                {
                    theLock.Lock(me, ref myBackoffs, ref myStreak);
                    if (Interlocked.Increment(ref inside) > 1) Interlocked.Increment(ref violations);
                    Thread.SpinWait(20);                                  // --- критическая секция ---
                    myEntries++;
                    Interlocked.Decrement(ref inside);
                    theLock.Unlock(me);
                }
                entries[me] = myEntries; backoffs[me] = myBackoffs; streaks[me] = myStreak;
            }) { IsBackground = true, Name = $"T{me}" };
            threads[i].Start();
        }

        var sw = Stopwatch.StartNew();
        startGate.Set();
        Thread.Sleep(duration);
        Volatile.Write(ref stop, true);
        foreach (var t in threads) t.Join();
        sw.Stop();

        long totalEntries = entries.Sum(), totalBackoffs = backoffs.Sum();
        Console.WriteLine($"Полезная работа (входов в КС):  T0 = {entries[0]:N0}, T1 = {entries[1]:N0}, всего {totalEntries:N0}");
        Console.WriteLine($"Бесполезные уступки (backoff):  T0 = {backoffs[0]:N0}, T1 = {backoffs[1]:N0}, всего {totalBackoffs:N0}");
        Console.WriteLine($"Самая длинная серия уступок подряд перед одним входом: {streaks.Max():N0}");
        Console.WriteLine($"Нарушений взаимного исключения: {violations}");

        if (totalBackoffs > 0)
        {
            double wasted = totalEntries == 0 ? double.PositiveInfinity : (double)totalBackoffs / totalEntries;
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine($"LIVELOCK-ЭФФЕКТ: однажды потоки уступали друг другу {streaks.Max():N0} раз подряд, прежде чем кто-то вошёл.");
            Console.WriteLine($"В среднем на каждый полезный вход приходится {wasted:0.00} бесполезных уступок.");
            Console.WriteLine("Потоки не стоят (deadlock-а нет), CPU загружен, а работа делается медленно.");
            Console.WriteLine("В реальности случайные задержки рано или поздно ломают симметрию — но НИЧТО этого не гарантирует.");
            Console.WriteLine("TLC доказал: существует бесконечное поведение, в котором никто не войдёт (L7_Ex3_Livelock_Polite).");
        }
        else
        {
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("Уступок нет: при конфликте turn сразу выбирает победителя. Прогресс гарантирован.");
        }
        Console.ResetColor();
        Console.WriteLine($"Время: {sw.ElapsedMilliseconds} мс\n");
    }
}

