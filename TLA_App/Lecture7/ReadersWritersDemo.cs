using System.Diagnostics;

namespace TLA_App.Lecture7;

/// <summary>Замок «читатели-писатели» с ограничением времени ожидания писателя.</summary>
public interface IReadWriteLock
{
    string Name { get; }
    void EnterRead();
    void ExitRead();
    bool TryEnterWrite(TimeSpan timeout);
    void ExitWrite();
    int ActiveReaders { get; }
}

/// <summary>
/// Наивный RW-замок (TLA+: L7_Ex4_RW_Naive).
/// _state: N >= 0 — читают N читателей; -1 — пишет писатель.
/// Читатель входит, если никто не пишет. Писатель — если нет никого.
/// </summary>
public sealed class NaiveRwLock : IReadWriteLock
{
    private int _state;
    public string Name => "Наивный RW-замок: писатель ждёт, пока читателей станет 0";
    public int ActiveReaders => Math.Max(0, Volatile.Read(ref _state));

    public void EnterRead()
    {
        var spinner = new SpinWait();
        while (true)
        {
            int s = Volatile.Read(ref _state);
            if (s >= 0 && Interlocked.CompareExchange(ref _state, s + 1, s) == s) return;   // StartRead
            spinner.SpinOnce(sleep1Threshold: -1);
        }
    }

    public void ExitRead() => Interlocked.Decrement(ref _state);                            // EndRead

    public bool TryEnterWrite(TimeSpan timeout)
    {
        var sw = Stopwatch.StartNew();
        while (Interlocked.CompareExchange(ref _state, -1, 0) != 0)                         // StartWrite: только при 0 читателей
        {
            if (sw.Elapsed > timeout) return false;
            Thread.SpinWait(10);
        }
        return true;
    }

    public void ExitWrite() => Volatile.Write(ref _state, 0);                               // EndWrite
}

/// <summary>
/// RW-замок с приоритетом писателя (TLA+: L7_Ex4_RW_WriterPriority).
/// Единственное отличие: новый читатель не входит, пока какой-то писатель ЖДЁТ.
/// </summary>
public sealed class WriterPriorityRwLock : IReadWriteLock
{
    private int _state;
    private int _writersWaiting;
    public string Name => "RW-замок с приоритетом писателя: ждущий писатель останавливает новых читателей";
    public int ActiveReaders => Math.Max(0, Volatile.Read(ref _state));

    public void EnterRead()
    {
        var spinner = new SpinWait();
        while (true)
        {
            if (Volatile.Read(ref _writersWaiting) == 0)                                    // <- НОВОЕ: ~WriterWaiting
            {
                int s = Volatile.Read(ref _state);
                if (s >= 0 && Interlocked.CompareExchange(ref _state, s + 1, s) == s) return;
            }
            spinner.SpinOnce(sleep1Threshold: -1);
        }
    }

    public void ExitRead() => Interlocked.Decrement(ref _state);

    public bool TryEnterWrite(TimeSpan timeout)
    {
        Interlocked.Increment(ref _writersWaiting);                                         // WantWrite: «я жду»
        try
        {
            var sw = Stopwatch.StartNew();
            while (Interlocked.CompareExchange(ref _state, -1, 0) != 0)
            {
                if (sw.Elapsed > timeout) return false;
                Thread.SpinWait(10);
            }
            return true;
        }
        finally
        {
            Interlocked.Decrement(ref _writersWaiting);
        }
    }

    public void ExitWrite() => Volatile.Write(ref _state, 0);
}

/// <summary>
/// Несколько читателей непрерывно читают «кэш прав доступа», один писатель (администратор)
/// пытается несколько раз записать в него (например, заблокировать скомпрометированный аккаунт).
/// </summary>
public static class ReadersWritersDemo
{
    public static void Run(IReadWriteLock rw, int readerCount, int writeAttempts, TimeSpan writeTimeout)
    {
        Console.ForegroundColor = ConsoleColor.Cyan;
        Console.WriteLine($"=== {rw.Name} ===");
        Console.ResetColor();
        Console.WriteLine($"Читателей: {readerCount} (читают без пауз, «внахлёст»). Писатель: {writeAttempts} попыток записи, ждёт не дольше {writeTimeout.TotalMilliseconds:0} мс каждую.\n");

        long reads = 0, violations = 0;
        int writing = 0;
        bool stop = false;

        var readers = new Thread[readerCount];
        for (int i = 0; i < readerCount; i++)
        {
            readers[i] = new Thread(() =>
            {
                long myReads = 0;
                while (!Volatile.Read(ref stop))
                {
                    rw.EnterRead();
                    if (Volatile.Read(ref writing) != 0) Interlocked.Increment(ref violations);
                    Thread.SpinWait(2_000);                       // читаем кэш
                    rw.ExitRead();
                    myReads++;
                }
                Interlocked.Add(ref reads, myReads);
            }) { IsBackground = true, Name = $"Reader{i}" };
            readers[i].Start();
        }

        Thread.Sleep(100);                                         // читатели «разогнались»

        int succeeded = 0;
        for (int attempt = 1; attempt <= writeAttempts; attempt++)
        {
            var sw = Stopwatch.StartNew();
            bool ok = rw.TryEnterWrite(writeTimeout);              // wpc = "wait"
            sw.Stop();
            if (ok)
            {
                Volatile.Write(ref writing, 1);                    // wpc = "writing"
                if (rw.ActiveReaders != 0) Interlocked.Increment(ref violations);
                Thread.SpinWait(5_000);                            // записываем
                Volatile.Write(ref writing, 0);
                rw.ExitWrite();
                succeeded++;
                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine($"  Запись #{attempt}: писатель ждал {sw.Elapsed.TotalMilliseconds,8:0.000} мс — ЗАПИСАЛ");
            }
            else
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine($"  Запись #{attempt}: писатель ждал {sw.Elapsed.TotalMilliseconds,8:0.000} мс — НЕ ДОЖДАЛСЯ (читатели не кончаются)");
            }
            Console.ResetColor();
            Thread.Sleep(20);
        }

        Volatile.Write(ref stop, true);
        foreach (var t in readers) t.Join();

        Console.WriteLine();
        Console.WriteLine($"Читатели выполнили {reads:N0} чтений. Нарушений RWExclusion: {violations}.");
        Console.ForegroundColor = succeeded == writeAttempts ? ConsoleColor.Green : ConsoleColor.Red;
        Console.WriteLine(succeeded == writeAttempts
            ? $"Писатель выполнил все {writeAttempts} записей. WriterProgress выполняется."
            : $"ГОЛОДАНИЕ ПИСАТЕЛЯ: успешно {succeeded} из {writeAttempts}. Система «работает» (чтения идут), а блокировка аккаунта не проходит!");
        Console.ResetColor();
        Console.WriteLine();
    }
}

