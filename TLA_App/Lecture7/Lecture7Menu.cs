namespace TLA_App.Lecture7;

/// <summary>
/// Меню демонстраций лекции 7: liveness, справедливость, голодание, livelock.
/// Запуск одного пункта без меню: dotnet run -c Release -- 3
/// </summary>
public static class Lecture7Menu
{
    private static readonly TimeSpan Duration = TimeSpan.FromSeconds(3);
    private static readonly int Threads = Math.Clamp(Environment.ProcessorCount / 2, 2, 4);
    private static readonly int ReaderThreads = Math.Clamp(Environment.ProcessorCount / 2, 2, 4);

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
            Console.WriteLine("========== ЛЕКЦИЯ 7: LIVENESS, СПРАВЕДЛИВОСТЬ, ГОЛОДАНИЕ, LIVELOCK ==========");
            Console.ResetColor();
            Console.WriteLine("1. Жадные потоки на lock (Monitor)                  [ожидаем: перекос, голодание]");
            Console.WriteLine("2. Жадные потоки на Ticket Lock (FIFO)              [ожидаем: честно]");
            Console.WriteLine("3. «Вежливые» потоки                                [ожидаем: livelock-эффект]");
            Console.WriteLine("4. Петерсон                                         [ожидаем: прогресс]");
            Console.WriteLine("5. Читатели-писатели, наивный замок                 [ожидаем: голодание писателя]");
            Console.WriteLine("6. Читатели-писатели, приоритет писателя            [ожидаем: OK]");
            Console.WriteLine("0. Выход");
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
            case "1": FairnessDemo.Run(new MonitorLock(), Threads, Duration); break;
            case "2": FairnessDemo.Run(new TicketLock(), Threads, Duration); break;
            case "3": LivelockDemo.Run(new PoliteLock(), Duration); break;
            case "4": LivelockDemo.Run(new PetersonLock(), Duration); break;
            case "5": ReadersWritersDemo.Run(new NaiveRwLock(), ReaderThreads, 5, TimeSpan.FromSeconds(1)); break;
            case "6": ReadersWritersDemo.Run(new WriterPriorityRwLock(), ReaderThreads, 5, TimeSpan.FromSeconds(1)); break;
            default: Console.WriteLine("Неверный выбор.\n"); break;
        }
    }
}

