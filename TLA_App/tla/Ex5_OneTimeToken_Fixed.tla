------------------------- MODULE Ex5_OneTimeToken_Fixed -------------------------
(***************************************************************************)
(* Пример 5 (Исправленный вариант). Атомарное погашение токена (CAS).      *)
(* Проверка и списание объединены в единую неделимую транзакцию базы:      *)
(*   UPDATE vouchers SET status = 'USED' WHERE code = 'X' AND status = 'UNUSED'*)
(* Только ОДИН запрос успеет перевести токен из "UNUSED" в "USED"!          *)
(* Второй запрос получит отказ ("rejected") и 0 бонусов.                    *)
(***************************************************************************)
EXTENDS Integers

VARIABLES 
    token_status,   \* Статус токена: "UNUSED", "USED"
    user_balance,   \* Баланс бонусов пользователя
    req1_state,     \* Состояние запроса 1: "idle", "success", "rejected"
    req2_state      \* Состояние запроса 2: "idle", "success", "rejected"

vars == <<token_status, user_balance, req1_state, req2_state>>

Init ==
    /\ token_status = "UNUSED"
    /\ user_balance = 0
    /\ req1_state = "idle"
    /\ req2_state = "idle"

\* Запрос 1: атомарная попытка погасить токен (CAS)
Req1_Redeem ==
    /\ req1_state = "idle"
    /\ IF token_status = "UNUSED"
       THEN /\ token_status' = "USED"
            /\ user_balance' = user_balance + 500
            /\ req1_state' = "success"
       ELSE /\ req1_state' = "rejected"
            /\ UNCHANGED <<token_status, user_balance>>
    /\ UNCHANGED req2_state

\* Запрос 2: атомарная попытка погасить токен (CAS)
Req2_Redeem ==
    /\ req2_state = "idle"
    /\ IF token_status = "UNUSED"
       THEN /\ token_status' = "USED"
            /\ user_balance' = user_balance + 500
            /\ req2_state' = "success"
       ELSE /\ req2_state' = "rejected"
            /\ UNCHANGED <<token_status, user_balance>>
    /\ UNCHANGED req1_state

\* Завершение обоих запросов
Done ==
    /\ req1_state \in {"success", "rejected"}
    /\ req2_state \in {"success", "rejected"}
    /\ UNCHANGED vars

Next ==
    \/ Req1_Redeem
    \/ Req2_Redeem
    \/ Done

-----------------------------------------------------------------------------
\* ИНВАРИАНТ БЕЗОПАСНОСТИ:
\* Одноразовый токен на 500 бонусов НИКОГДА не должен дать пользователю > 500!
MaxOneRedemption ==
    user_balance <= 500

=============================================================================
