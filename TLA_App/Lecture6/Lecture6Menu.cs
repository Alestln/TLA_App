namespace TLA_App.Lecture6;

/// <summary>
/// Меню демонстраций лекции 6: взаимное исключение, deadlock, голодание, алгоритм Петерсона.
/// Запуск напрямую: dotnet run -- l6
/// Запуск одного пункта без меню: dotnet run -- l6 2
/// </summary>
public static class Lecture6Menu
{
    private const int Iterations = 200_000;
    private static readonly TimeSpan Timeout = TimeSpan.FromSeconds(5);

    public static void Run(string? directChoice = null)
    {
        if (directChoice is not null)
        {
            Execute(directChoice);
            return;
        }

        while (true)
        {
            Console.ForegroundColor = ConsoleColor.Cyan;
            Console.WriteLine("================ ЛЕКЦИЯ 6: ВЗАИМНОЕ ИСКЛЮЧЕНИЕ И DEADLOCK ================");
            Console.ResetColor();
            Console.WriteLine("1. Попытка 1: проверить -> занять (CheckThenSet)     [ожидаем: гонка]");
            Console.WriteLine("2. Попытка 2: занять -> ждать (SetThenWait)          [ожидаем: deadlock]");
            Console.WriteLine("3. Перевод денег: lock(from) -> lock(to)              [ожидаем: deadlock]");
            Console.WriteLine("4. Перевод денег: глобальный порядок замков           [ожидаем: OK]");
            Console.WriteLine("5. Попытка 3: строгая очередь turn, сосед ушёл        [ожидаем: голодание]");
            Console.WriteLine("6. Петерсон с переставленными строками                [ожидаем: гонка]");
            Console.WriteLine("7. Петерсон правильный (+ барьер памяти)              [ожидаем: OK]");
            Console.WriteLine("8. Петерсон БЕЗ барьера памяти (ловушка железа)       [возможна гонка]");
            Console.WriteLine("9. Эталон: lock из .NET                               [ожидаем: OK]");
            Console.WriteLine("0. Назад");
            Console.Write("\nВаш выбор: ");

            var choice = Console.ReadLine()?.Trim('\uFEFF', ' ', '\r', '\n', '\t');
            if (string.IsNullOrEmpty(choice) || choice == "0") return;
            Console.WriteLine();
            Execute(choice);
        }
    }

    private static void Execute(string choice)
    {
        switch (choice)
        {
            case "1": MutexRaceRunner.Run(new CheckThenSetMutex(), Iterations, Iterations, Timeout); break;
            case "2": MutexRaceRunner.Run(new SetThenWaitMutex(), Iterations, Iterations, Timeout); break;
            case "3": TransferDeadlockDemo.Run(orderedLocks: false); break;
            case "4": TransferDeadlockDemo.Run(orderedLocks: true); break;
            // Поток 0 зайдёт в КС всего 3 раза и завершится (TLA+: Quit), поток 1 хочет больше.
            case "5": MutexRaceRunner.Run(new StrictTurnMutex(), 3, Iterations, Timeout); break;
            case "6": MutexRaceRunner.Run(new PetersonMutex(swapLines: true, fullFence: true), Iterations, Iterations, Timeout); break;
            case "7": MutexRaceRunner.Run(new PetersonMutex(swapLines: false, fullFence: true), Iterations, Iterations, Timeout); break;
            case "8": MutexRaceRunner.Run(new PetersonMutex(swapLines: false, fullFence: false), Iterations, Iterations, Timeout); break;
            case "9": MutexRaceRunner.Run(new MonitorMutex(), Iterations, Iterations, Timeout); break;
            default: Console.WriteLine("Неверный выбор.\n"); break;
        }
    }
}
