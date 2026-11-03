using System;

namespace TLA_App;

/// <summary>
/// Лекция 7: Верификация свойств живучести (Liveness), справедливость (WF / SF),
/// скрытые блокировки (stuttering, livelock) и голодание процессов (starvation).
/// Точка входа для демонстраций в C#.
/// </summary>
public class Program
{
    public static void Main(string[] args)
    {
        Console.OutputEncoding = System.Text.Encoding.UTF8;

        // dotnet run -c Release          -> интерактивное меню
        // dotnet run -c Release -- 3     -> запуск пункта 3 напрямую
        string? choice = args.Length > 0 ? args[0] : null;

        Lecture7.Lecture7Menu.Run(choice);
    }
}
