using System.Diagnostics;

namespace TLA_App.Lecture7;

/// <summary>Простой замок для нескольких потоков.</summary>
public interface ISimpleLock
{
    string Name { get; }
    void Enter();
    void Exit();
}

/// <summary>
/// Обычный lock (Monitor) из .NET. Взаимное исключение гарантировано,
/// но порядок обслуживания НЕ гарантирован: поток, только что отпустивший замок,
/// часто сразу же захватывает его снова («жадный» поток).
/// В терминах TLA+ это замок без сильной справедливости (L7_Ex2_Lock_WF).
/// </summary>
public sealed class MonitorLock : ISimpleLock
{
    private readonly object _sync = new();
    public string Name => "lock (Monitor) из .NET — порядок входа не гарантирован";
    public void Enter() => Monitor.Enter(_sync);
    public void Exit() => Monitor.Exit(_sync);
}

/// <summary>
/// Ticket Lock — честный FIFO-замок, как очередь с талончиками в банке.
/// Модель в TLA+: L7_Ex2_Lock_FIFO (достаточно слабой справедливости).
/// </summary>
public sealed class TicketLock : ISimpleLock
{
    private int _nextTicket;   // следующий свободный талончик
    private int _nowServing;   // какой талончик сейчас обслуживается

    public string Name => "Ticket Lock (очередь по талончикам, FIFO)";

    public void Enter()
    {
        int myTicket = Interlocked.Increment(ref _nextTicket) - 1;   // Request: взял талончик
        var spinner = new SpinWait();
        while (Volatile.Read(ref _nowServing) != myTicket)          // жду, пока я не первый в очереди
            spinner.SpinOnce(sleep1Threshold: -1);
        // Acquire: мой талончик вызвали
    }

    // Release: вызываю следующий талончик. Пишет только владелец замка.
    public void Exit() => Volatile.Write(ref _nowServing, _nowServing + 1);
}

/// <summary>
/// Несколько «жадных» потоков без остановки заходят в критическую секцию.
/// Измеряем: сколько раз вошёл каждый поток и сколько максимум ему пришлось ждать.
/// Неравномерность и огромное максимальное ожидание — симптомы голодания.
/// </summary>
public static class FairnessDemo
{
    public static void Run(ISimpleLock theLock, int threadCount, TimeSpan duration)
    {
        Console.ForegroundColor = ConsoleColor.Cyan;
        Console.WriteLine($"=== {theLock.Name} ===");
        Console.ResetColor();
        Console.WriteLine($"Потоков: {threadCount}, длительность: {duration.TotalSeconds:0} с. Каждый поток без пауз: lock -> работа -> unlock -> снова lock.\n");

        var entries = new long[threadCount];
        var maxWaitTicks = new long[threadCount];
        long inside = 0, violations = 0;
        bool stop = false;
        using var startGate = new ManualResetEventSlim(false);

        var threads = new Thread[threadCount];
        for (int i = 0; i < threadCount; i++)
        {
            int me = i;
            threads[i] = new Thread(() =>
            {
                startGate.Wait();
                while (!Volatile.Read(ref stop))
                {
                    long t0 = Stopwatch.GetTimestamp();
                    theLock.Enter();                                    // pc = "wait"
                    long waited = Stopwatch.GetTimestamp() - t0;        // pc = "cs"
                    if (waited > maxWaitTicks[me]) maxWaitTicks[me] = waited;

                    if (Interlocked.Increment(ref inside) > 1) Interlocked.Increment(ref violations);
                    Thread.SpinWait(200);                               // --- критическая секция ---
                    entries[me]++;
                    Interlocked.Decrement(ref inside);

                    theLock.Exit();                                     // pc = "idle" -> и сразу снова "wait"
                }
            }) { IsBackground = true, Name = $"T{me}" };
            threads[i].Start();
        }

        startGate.Set();
        Thread.Sleep(duration);
        Volatile.Write(ref stop, true);
        foreach (var t in threads) t.Join();

        long total = entries.Sum();
        Console.WriteLine(" Поток | Входов в КС  | Доля   | Макс. ожидание входа");
        Console.WriteLine("-------+--------------+--------+---------------------");
        for (int i = 0; i < threadCount; i++)
        {
            double share = total == 0 ? 0 : 100.0 * entries[i] / total;
            double maxMs = maxWaitTicks[i] * 1000.0 / Stopwatch.Frequency;
            Console.WriteLine($"  T{i}   | {entries[i],12:N0} | {share,5:0.0}% | {maxMs,10:0.000} мс");
        }

        double worstWaitMs = maxWaitTicks.Max() * 1000.0 / Stopwatch.Frequency;
        double ratio = entries.Max() == 0 ? 0 : (double)entries.Min() / entries.Max();
        Console.WriteLine();
        Console.WriteLine($"Всего входов: {total:N0}. Нарушений взаимного исключения: {violations}.");
        Console.WriteLine($"Справедливость (мин/макс входов): {ratio:0.00}   (1.00 = все потоки обслужены поровну)");

        bool unfair = worstWaitMs > 5 || ratio < 0.9;
        Console.ForegroundColor = unfair ? ConsoleColor.Red : ConsoleColor.Green;
        Console.WriteLine(unfair
            ? $"НЕСПРАВЕДЛИВО: доли потоков разные, самый «невезучий» ждал входа {worstWaitMs:0.0} мс, пока другие заходили снова и снова.\n" +
              "lock не обещает очередь: ничто не мешает одному потоку ждать сколь угодно долго (TLA+: L7_Ex2_Lock_WF)."
            : $"Честно: никто не ждал дольше {worstWaitMs:0.000} мс, потоки обслужены поровну (TLA+: L7_Ex2_Lock_FIFO).");
        Console.ResetColor();
        Console.WriteLine();
    }
}

