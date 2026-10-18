using System.Threading.Tasks;

namespace TLA_App;

/// <summary>
/// Уязвимая реализация шлюза (Vulnerable Gateway).
/// 
/// Назначение сущности:
/// Реализует ограничение параллельных сессий с типичной логической ошибкой:
/// разрыв во времени между проверкой условия (Time-of-Check) и действием (Time-of-Use).
/// Уязвимость: CWE-367 (TOCTOU) / CWE-362 (Race Condition).
/// </summary>
public class VulnerableGateway : IGateway
{
    private readonly int _maxSessions;
    private int _activeSessions = 0;

    public int ActiveSessions => _activeSessions;

    public VulnerableGateway(int maxSessions)
    {
        _maxSessions = maxSessions;
    }

    /// <summary>
    /// Метод входа в сессию с нарушением атомарности:
    /// 1. Проверяет, не исчерпан ли лимит.
    /// 2. Имитирует сетевую задержку или валидацию JWT (окно уязвимости).
    /// 3. Инкрементирует счетчик на основе устаревшего решения.
    /// </summary>
    public async Task<bool> TryEnterSessionAsync(int clientId)
    {
        // 1. TIME OF CHECK (TOC) — Проверка предусловия
        if (_activeSessions >= _maxSessions)
        {
            return false; // Отказ в обслуживании
        }

        // Окно уязвимости: другой поток успевает изменить _activeSessions!
        await Task.Delay(1);

        // 2. TIME OF USE (TOU) — Действие на основе устаревших данных
        _activeSessions++;
        return true;
    }

    /// <summary>
    /// Метод завершения сессии.
    /// </summary>
    public Task ReleaseSessionAsync(int clientId)
    {
        _activeSessions--;
        return Task.CompletedTask;
    }
}
