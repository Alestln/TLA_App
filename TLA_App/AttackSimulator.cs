using System;
using System.Threading;
using System.Threading.Tasks;

namespace TLA_App;

/// <summary>
/// Симулятор конкурентної атаки (Attack Simulator).
/// 
/// Мета сутності:
/// Емулює дії зловмисника, який генерує одночасний шквал паралельних запитів (Thundering Herd)
/// для експлуатації вікна конкурентності та перевірки інваріантів безпеки шлюзу в реальному часі.
/// </summary>
public class AttackSimulator
{
    private readonly int _concurrentAttackers;
    private readonly int _maxAllowedSessions;

    public AttackSimulator(int concurrentAttackers, int maxAllowedSessions)
    {
        _concurrentAttackers = concurrentAttackers;
        _maxAllowedSessions = maxAllowedSessions;
    }

    /// <summary>
    /// Метод запуску атаки:
    /// Створює N паралельних потоків, синхронізує їх старт через бар'єр (Barrier)
    /// і фіксує порушення інваріанта безпеки (Safety Invariant).
    /// </summary>
    public async Task RunAttackAsync(IGateway gateway)
    {
        Console.ForegroundColor = ConsoleColor.Cyan;
        Console.WriteLine($"\n[>>>] Запуск симуляції: {gateway.GetType().Name}");
        Console.WriteLine($"      Політика безпеки: ліміт одночасних сесій = {_maxAllowedSessions}");
        Console.WriteLine($"      Навантаження: {_concurrentAttackers} одночасних запитів (Thundering Herd)...\n");
        Console.ResetColor();

        int violationsCount = 0;
        int peakConcurrentSessions = 0;

        var barrier = new Barrier(_concurrentAttackers); // Бар'єр синхронізації одночасного удару
        var tasks = new Task[_concurrentAttackers];

        for (int i = 0; i < _concurrentAttackers; i++)
        {
            int clientId = i + 1;
            tasks[i] = Task.Run(async () =>
            {
                // Усі потоки блокуються тут, доки всі N клієнтів не будуть готові.
                // Після цього бар'єр відкривається, створюючи максимальний сплеск навантаження.
                barrier.SignalAndWait();

                bool entered = await gateway.TryEnterSessionAsync(clientId);
                if (entered)
                {
                    int current = gateway.ActiveSessions;

                    lock (gateway)
                    {
                        if (current > peakConcurrentSessions)
                            peakConcurrentSessions = current;
                    }

                    // Перевірка інваріанта безпеки
                    if (current > _maxAllowedSessions)
                    {
                        Interlocked.Increment(ref violationsCount);
                        Console.ForegroundColor = ConsoleColor.Red;
                        Console.WriteLine($"[EXPLOIT!] Клієнт #{clientId:D2} отримав доступ! Активних: {current} > {_maxAllowedSessions} (ІНВАРІАНТ ПОРУШЕНО!)");
                        Console.ResetColor();
                    }
                    else
                    {
                        Console.ForegroundColor = ConsoleColor.Green;
                        Console.WriteLine($"[ALLOW]    Клієнт #{clientId:D2} успішно пройшов. Активних: {current}/{_maxAllowedSessions}");
                        Console.ResetColor();
                    }

                    // Емуляція роботи всередині захищеного контуру
                    await Task.Delay(50);

                    await gateway.ReleaseSessionAsync(clientId);
                }
                else
                {
                    Console.ForegroundColor = ConsoleColor.DarkGray;
                    Console.WriteLine($"[DENY]     Клієнт #{clientId:D2} відхилений шлюзом (429 Too Many Requests)");
                    Console.ResetColor();
                }
            });
        }

        await Task.WhenAll(tasks);

        // Формування звіту аудиту
        Console.WriteLine("\n--------------------------------------------------------------------------------");
        Console.WriteLine($"Звіт аудиту безпеки для {gateway.GetType().Name}:");
        Console.WriteLine($"  - Пікова кількість одночасних сесій: {peakConcurrentSessions} (Ліміт: {_maxAllowedSessions})");
        if (violationsCount > 0)
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine($"  - СТАТУС: УРАЗЛИВІСТЬ ВИЯВЛЕНО! {violationsCount} сесій перевищили ліміт безпеки.");
            Console.WriteLine($"  - Тип загрози: CWE-367 TOCTOU / стан гонки при паралельній обробці.");
            Console.ResetColor();
        }
        else
        {
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine($"  - СТАТУС: Інваріант безпеки втримано (0 порушень).");
            Console.ResetColor();
        }
        Console.WriteLine("--------------------------------------------------------------------------------\n");
    }
}
