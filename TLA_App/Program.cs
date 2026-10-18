using System;
using System.Threading.Tasks;

namespace TLA_App;

/// <summary>
/// Точка входу в демонстраційний додаток.
/// Забезпечує інтерактивне керування симуляціями під час лекції.
/// </summary>
public class Program
{
    private const int MAX_SESSIONS = 5;         // Ліміт шлюзу за політикою безпеки
    private const int CONCURRENT_ATTACKERS = 20; // Кількість одночасних запитів атакуючого

    public static async Task Main(string[] args)
    {
        Console.OutputEncoding = System.Text.Encoding.UTF8;
        Console.ForegroundColor = ConsoleColor.Cyan;
        Console.WriteLine("================================================================================");
        Console.WriteLine("  ЛЕКЦІЯ 5: МОДЕЛЮВАННЯ РОЗПОДІЛЕНИХ СИСТЕМ ТА TLA+ (КІБЕРБЕЗПЕКА)");
        Console.WriteLine("  Тема: Від недетермінованого коду C# до автомата станів у TLA+");
        Console.WriteLine("================================================================================\n");
        Console.ResetColor();

        var simulator = new AttackSimulator(CONCURRENT_ATTACKERS, MAX_SESSIONS);

        while (true)
        {
            Console.WriteLine("Оберіть дію для демонстрації студентам:");
            Console.WriteLine("1. Запустити УРАЗЛИВИЙ шлюз (VulnerableGateway - TOCTOU)");
            Console.WriteLine("2. Запустити ВИПРАВЛЕНИЙ шлюз (SecureGateway - Lock-free CAS)");
            Console.WriteLine("3. Вихід");
            Console.Write("\nВаш вибір (1-3): ");

            var choice = Console.ReadLine()?.Trim('\uFEFF', ' ', '\r', '\n', '\t');
            if (string.IsNullOrWhiteSpace(choice) || choice.Contains("3"))
            {
                Console.WriteLine("Завершення роботи.");
                return;
            }
            Console.WriteLine();

            switch (choice)
            {
                case "1":
                    await simulator.RunAttackAsync(new VulnerableGateway(MAX_SESSIONS));
                    break;
                case "2":
                    await simulator.RunAttackAsync(new SecureGateway(MAX_SESSIONS));
                    break;
                default:
                    Console.WriteLine("Невірний вибір. Введіть 1, 2 або 3.");
                    break;
            }
        }
    }
}