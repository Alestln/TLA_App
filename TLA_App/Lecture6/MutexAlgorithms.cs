namespace TLA_App.Lecture6;

/// <summary>
/// Замок (mutex) для ДВУХ потоков с номерами 0 и 1.
/// Каждая реализация — это одна из «попыток» из лекции 6,
/// построчно совпадающая с соответствующей TLA+-спецификацией.
/// </summary>
public interface ITwoThreadMutex
{
    string Name { get; }

    /// <summary>Войти в критическую секцию. false = демо прервано (поток завис и его «разбудили»).</summary>
    bool Lock(int me);

    /// <summary>Выйти из критической секции.</summary>
    void Unlock(int me);

    /// <summary>Снимок внутренних переменных замка — печатаем при зависании.</summary>
    string DescribeState();

    /// <summary>Аварийно разбудить потоки, застрявшие в цикле ожидания (только для демо).</summary>
    void Abort();
}

/// <summary>
/// Общая часть «самодельных» замков: цикл ожидания while (условие) { } с аварийным выходом.
/// </summary>
public abstract class SpinMutexBase : ITwoThreadMutex
{
    private volatile bool _aborted;

    public abstract string Name { get; }
    public abstract bool Lock(int me);
    public abstract void Unlock(int me);
    public abstract string DescribeState();

    public void Abort() => _aborted = true;

    protected static int Other(int me) => 1 - me;

    /// <summary>Аналог <c>while (condition()) { }</c>. Возвращает false, если демо прервали.</summary>
    protected bool SpinWhile(Func<bool> condition)
    {
        var spinner = new SpinWait();
        while (condition())
        {
            if (_aborted) return false;
            spinner.SpinOnce(sleep1Threshold: -1); // крутимся/уступаем CPU, но не засыпаем
        }
        return true;
    }

    /// <summary>
    /// «Окно» между двумя строками кода: имитирует вытеснение потока планировщиком ОС.
    /// В реальном коде это может быть логирование, проверка JWT, запрос к БД...
    /// </summary>
    protected static void Window() => Thread.SpinWait(300);
}

// ============================================================================
// ПОПЫТКА 1. Проверить, потом занять.   TLA+: tla/L6_Ex2_Mutex_CheckThenSet.tla
// ============================================================================
public sealed class CheckThenSetMutex : SpinMutexBase
{
    private readonly int[] _flag = new int[2]; // 1 = «табличка Занято» висит

    public override string Name => "Попытка 1: проверить флаг соседа -> поднять свой (CheckThenSet)";

    public override bool Lock(int me)
    {
        // 1. ПРОВЕРИЛ: ждём, пока у соседа опущен флаг   (TLA+: Check)
        if (!SpinWhile(() => Volatile.Read(ref _flag[Other(me)]) == 1)) return false;

        Window(); // <-- окно уязвимости TOCTOU: сосед тоже успевает проверить

        // 2. ЗАНЯЛ: поднимаем свой флаг                   (TLA+: SetAndEnter)
        Volatile.Write(ref _flag[me], 1);
        return true;
    }

    public override void Unlock(int me) => Volatile.Write(ref _flag[me], 0); // (TLA+: Exit)

    public override string DescribeState() => $"flag = [{_flag[0]}, {_flag[1]}]";
}

// ============================================================================
// ПОПЫТКА 2. Сначала занять, потом ждать.   TLA+: tla/L6_Ex3_Mutex_SetThenWait.tla
// ============================================================================
public sealed class SetThenWaitMutex : SpinMutexBase
{
    private readonly int[] _flag = new int[2];

    public override string Name => "Попытка 2: поднять свой флаг -> ждать, пока сосед опустит (SetThenWait)";

    public override bool Lock(int me)
    {
        // 1. Поднимаем флаг «я хочу войти»                (TLA+: Want)
        //    Interlocked = запись с полным барьером памяти, чтобы флаг сразу стал виден соседу.
        Interlocked.Exchange(ref _flag[me], 1);

        // 2. Ждём, пока сосед не хочет                    (TLA+: Enter)
        return SpinWhile(() => Volatile.Read(ref _flag[Other(me)]) == 1);
    }

    public override void Unlock(int me) => Volatile.Write(ref _flag[me], 0);

    public override string DescribeState() =>
        $"flag = [{_flag[0]}, {_flag[1]}]  <- оба хотят войти, и каждый ждёт, пока другой опустит флаг";
}

// ============================================================================
// ПОПЫТКА 3. Строгая очередь.   TLA+: tla/L6_Ex5_Mutex_StrictTurn.tla
// ============================================================================
public sealed class StrictTurnMutex : SpinMutexBase
{
    private int _turn; // чья очередь: 0 или 1

    public override string Name => "Попытка 3: строгая очередь turn (StrictTurn)";

    public override bool Lock(int me) =>
        SpinWhile(() => Volatile.Read(ref _turn) != me);           // (TLA+: Enter, guard turn = p)

    public override void Unlock(int me) =>
        Volatile.Write(ref _turn, Other(me));                       // (TLA+: Exit, turn' = Other(p))

    public override string DescribeState() =>
        $"turn = {_turn}  <- очередь у потока, который уже завершил работу и никогда её не отдаст";
}

// ============================================================================
// АЛГОРИТМ ПЕТЕРСОНА.   TLA+: tla/L6_Ex6_Peterson_Fixed.tla / _Buggy.tla
// ============================================================================
public sealed class PetersonMutex : SpinMutexBase
{
    private readonly int[] _flag = new int[2];
    private int _turn;
    private readonly bool _swapLines;
    private readonly bool _fullFence;

    /// <param name="swapLines">true = переставить строки flag/turn (ошибочный вариант).</param>
    /// <param name="fullFence">true = полный барьер памяти после записей (нужен на реальном CPU).</param>
    public PetersonMutex(bool swapLines, bool fullFence)
    {
        _swapLines = swapLines;
        _fullFence = fullFence;
    }

    public override string Name =>
        (_swapLines ? "Петерсон с ПЕРЕСТАВЛЕННЫМИ строками (turn -> flag)" : "Петерсон (flag -> turn)")
        + (_fullFence ? " + барьер памяти" : " БЕЗ барьера памяти");

    public override bool Lock(int me)
    {
        int other = Other(me);

        if (!_swapLines)
        {
            Volatile.Write(ref _flag[me], 1);   // 1. я хочу войти        (TLA+: SetFlag)
            Volatile.Write(ref _turn, other);   // 2. проходи первым      (TLA+: SetTurn)
        }
        else
        {
            Volatile.Write(ref _turn, other);   // 1. (переставлено!)
            Window();                           //    поток вытеснили между строками
            Volatile.Write(ref _flag[me], 1);   // 2. (переставлено!)
        }

        // Барьер: запрещает процессору выполнить чтение ниже РАНЬШЕ записей выше.
        if (_fullFence) Interlocked.MemoryBarrier();

        // 3. while (flag[other] && turn == other) { }                  (TLA+: Enter)
        return SpinWhile(() => Volatile.Read(ref _flag[other]) == 1 && Volatile.Read(ref _turn) == other);
    }

    public override void Unlock(int me) => Volatile.Write(ref _flag[me], 0); // (TLA+: Exit)

    public override string DescribeState() => $"flag = [{_flag[0]}, {_flag[1]}], turn = {_turn}";
}

// ============================================================================
// ЭТАЛОН: обычный lock из .NET (внутри — атомарные инструкции CPU + очередь ОС)
// ============================================================================
public sealed class MonitorMutex : ITwoThreadMutex
{
    private readonly object _gate = new();

    public string Name => "Эталон: lock (Monitor) из .NET";
    public bool Lock(int me) { Monitor.Enter(_gate); return true; }
    public void Unlock(int me) => Monitor.Exit(_gate);
    public string DescribeState() => "—";
    public void Abort() { }
}
