using System.Diagnostics;

namespace TLA_App.Lecture6;

/// <summary>
/// «Датчик» внутри критической секции. Ловит два симптома:
///  1) нарушение взаимного исключения: в секции оказалось больше одного потока;
///  2) потерянные обновления неатомарного счётчика (как в лекции 5).
/// </summary>
public sealed class CriticalSectionProbe
{
    private int _inside;
    private int _violations;

    /// <summary>Обычное поле, без Interlocked: защищено ТОЛЬКО тестируемым замком.</summary>
    public long Counter;

    public int Violations => Volatile.Read(ref _violations);

    public void Enter()
    {
        if (Interlocked.Increment(ref _inside) > 1)       // кто-то уже внутри?
            Interlocked.Increment(ref _violations);       // -> MutualExclusion нарушен
    }

    public void Work()
    {
        long value = Counter;        // прочитать
        Thread.SpinWait(20);         // «полезная работа»
        Counter = value + 1;         // записать
    }

    public void Exit() => Interlocked.Decrement(ref _inside);
}

/// <summary>
/// Запускает два потока, которые много раз заходят в критическую секцию через тестируемый замок,
/// и печатает результат: нарушения, потерянные обновления или зависание (deadlock / голодание).
/// </summary>
public static class MutexRaceRunner
{
    public static void Run(ITwoThreadMutex mutex, int iterationsT0, int iterationsT1, TimeSpan timeout)
    {
        var probe = new CriticalSectionProbe();
        int[] iterations = { iterationsT0, iterationsT1 };
        long[] progress = new long[2];
        using var startGate = new ManualResetEventSlim(false);

        Console.ForegroundColor = ConsoleColor.Cyan;
        Console.WriteLine($"=== {mutex.Name} ===");
        Console.ResetColor();
        Console.WriteLine($"Поток 0: {iterationsT0:N0} входов в КС, поток 1: {iterationsT1:N0} входов в КС. Таймаут: {timeout.TotalSeconds:0} с.");

        var threads = new Thread[2];
        for (int i = 0; i < 2; i++)
        {
            int me = i;
            threads[i] = new Thread(() =>
            {
                startGate.Wait();                          // стартуем одновременно
                for (int k = 0; k < iterations[me]; k++)
                {
                    if (!mutex.Lock(me)) return;           // демо прервано: поток висел в ожидании
                    probe.Enter();
                    probe.Work();                          // --- критическая секция ---
                    probe.Exit();
                    mutex.Unlock(me);
                    Interlocked.Increment(ref progress[me]);
                }
            })
            { IsBackground = true, Name = $"T{me}" };
            threads[i].Start();
        }

        var sw = Stopwatch.StartNew();
        startGate.Set();

        bool finished = threads.All(t => t.Join(Remaining(timeout, sw)));
        sw.Stop();

        long expected = iterationsT0 + iterationsT1;
        Console.WriteLine($"Прогресс: поток 0 = {progress[0]:N0}/{iterationsT0:N0}, поток 1 = {progress[1]:N0}/{iterationsT1:N0}");

        if (!finished)
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine($"ЗАВИСАНИЕ: за {timeout.TotalSeconds:0} с потоки не завершились. Счётчики прогресса стоят на месте.");
            Console.WriteLine($"Состояние замка: {mutex.DescribeState()}");
            Console.WriteLine("Это то же самое состояние, которое TLC печатает после 'Deadlock reached'.");
            Console.ResetColor();
            mutex.Abort();                                  // будим застрявшие потоки, чтобы продолжить лекцию
            foreach (var t in threads) t.Join(TimeSpan.FromSeconds(1));
        }

        long lost = Math.Max(0, Math.Min(progress[0] + progress[1], expected) - probe.Counter);
        Console.WriteLine($"Счётчик: ожидалось {progress[0] + progress[1]:N0}, получено {probe.Counter:N0} (потеряно {lost:N0})");

        if (probe.Violations > 0)
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine($"НАРУШЕНИЕ ВЗАИМНОГО ИСКЛЮЧЕНИЯ: оба потока были в КС одновременно {probe.Violations:N0} раз(а).");
        }
        else if (finished)
        {
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("Нарушений нет, оба потока завершили работу.");
        }
        Console.ResetColor();
        Console.WriteLine($"Время: {sw.ElapsedMilliseconds} мс\n");
    }

    private static TimeSpan Remaining(TimeSpan timeout, Stopwatch sw)
    {
        var left = timeout - sw.Elapsed;
        return left > TimeSpan.Zero ? left : TimeSpan.Zero;
    }
}
