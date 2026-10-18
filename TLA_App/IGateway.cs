using System.Threading.Tasks;

namespace TLA_App;

/// <summary>
/// Интерфейс сетевого шлюза (API Gateway).
/// Описывает контракт контроля сессий для защиты внутренней инфраструктуры от перегрузки (DoS).
/// </summary>
public interface IGateway
{
    /// <summary>
    /// Текущее количество активных сессий в шлюзе.
    /// </summary>
    int ActiveSessions { get; }

    /// <summary>
    /// Запрос клиента на вход в защищенную сессию.
    /// </summary>
    /// <param name="clientId">Идентификатор клиента</param>
    /// <returns>true, если запрос разрешен политикой безопасности; иначе false (429)</returns>
    Task<bool> TryEnterSessionAsync(int clientId);

    /// <summary>
    /// Завершение сессии и возврат слота пропускной способности шлюза.
    /// </summary>
    /// <param name="clientId">Идентификатор клиента</param>
    Task ReleaseSessionAsync(int clientId);
}
