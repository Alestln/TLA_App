using System;

namespace TLA_App;

/// <summary>
/// Лекция 6: Инварианты безопасности, алгоритмы взаимного исключения и Deadlock.
/// Точка входа для демонстраций в C#.
/// </summary>
public class Program
{
    public static void Main(string[] args)
    {
        Console.OutputEncoding = System.Text.Encoding.UTF8;

        // Поддержка запуска:
        // dotnet run                  -> интерактивное меню
        // dotnet run -- 3             -> запуск пункта 3 напрямую
        // dotnet run -- l6 3          -> совместимость с вызовом через префикс
        string? choice = null;
        if (args.Length > 0)
        {
            choice = args[0].Equals("l6", StringComparison.OrdinalIgnoreCase)
                ? (args.Length > 1 ? args[1] : null)
                : args[0];
        }

        Lecture6.Lecture6Menu.Run(choice);
    }
}