using System.Threading;
using System.Threading.Tasks;

namespace TLA_App;

/// <summary>
/// Захищена реалізація шлюзу (Secure Gateway).
/// 
/// Мета сутності:
/// Реалізує атомарний перехід стану відповідно до математичної специфікації TLA+.
/// Використовує апаратну атомарну операцію CAS (Compare-And-Swap) через Interlocked.CompareExchange.
/// </summary>
public class SecureGateway : IGateway
{
    private readonly int _maxSessions;
    private int _activeSessions = 0;

    public int ActiveSessions => Volatile.Read(ref _activeSessions);

    public SecureGateway(int maxSessions)
    {
        _maxSessions = maxSessions;
    }

    /// <summary>
    /// Метод атомарного входу в сесію:
    /// Реалізує неподільний квант перевірки та зміни стану за допомогою Lock-free CAS-петлі.
    /// </summary>
    public async Task<bool> TryEnterSessionAsync(int clientId)
    {
        // Навіть за наявності тривалої валідації JWT/I/O:
        await Task.Delay(1);

        // Атомарна транзакція стану (CAS Loop)
        while (true)
        {
            int current = Volatile.Read(ref _activeSessions);
            if (current >= _maxSessions)
            {
                return false; // Ліміт вичерпано
            }

            // Неподільна операція: перевіряємо, чи _activeSessions досі current,
            // і тільки тоді записуємо current + 1.
            if (Interlocked.CompareExchange(ref _activeSessions, current + 1, current) == current)
            {
                return true; // Успішно і безпечно захопили слот
            }

            // Якщо стан змінився паралельним потоком — повторюємо спробу з оновленими даними
        }
    }

    /// <summary>
    /// Атомарне звільнення сесії.
    /// </summary>
    public Task ReleaseSessionAsync(int clientId)
    {
        Interlocked.Decrement(ref _activeSessions);
        return Task.CompletedTask;
    }
}
