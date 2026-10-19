------------------------- MODULE Ex5_OneTimeToken_Buggy -------------------------
(***************************************************************************)
(* Пример 5 (Ошибочный вариант). Атака повторного погашения токена.        *)
(* Уязвимость: Promo Code / Password Reset Token Race Condition.           *)
(* Пользователь отправляет 2 параллельных HTTP-запроса на активацию токена.*)
(* Баг: проверка статуса токена и начисление бонуса разделены во времени.  *)
(* Итог: оба запроса видят "UNUSED", оба начисляют по 500 бонусов (итог:1000)*)
(***************************************************************************)
EXTENDS Integers

VARIABLES 
    token_status,   \* Статус токена: "UNUSED", "USED"
    user_balance,   \* Баланс бонусов пользователя
    req1_state,     \* Состояние запроса 1: "idle", "authorized", "success", "rejected"
    req2_state      \* Состояние запроса 2: "idle", "authorized", "success", "rejected"

vars == <<token_status, user_balance, req1_state, req2_state>>

Init ==
    /\ token_status = "UNUSED"
    /\ user_balance = 0
    /\ req1_state = "idle"
    /\ req2_state = "idle"

\* Запрос 1: проверка токена (Time-of-Check)
Req1_Check ==
    /\ req1_state = "idle"
    /\ IF token_status = "UNUSED"
       THEN /\ req1_state' = "authorized"
            /\ UNCHANGED token_status
       ELSE /\ req1_state' = "rejected"
            /\ UNCHANGED token_status
    /\ UNCHANGED <<user_balance, req2_state>>

\* Запрос 1: начисление бонуса и погашение токена (Time-of-Use)
Req1_Redeem ==
    /\ req1_state = "authorized"
    /\ user_balance' = user_balance + 500
    /\ token_status' = "USED"
    /\ req1_state' = "success"
    /\ UNCHANGED req2_state

\* Запрос 2: проверка токена (Time-of-Check)
Req2_Check ==
    /\ req2_state = "idle"
    /\ IF token_status = "UNUSED"
       THEN /\ req2_state' = "authorized"
            /\ UNCHANGED token_status
       ELSE /\ req2_state' = "rejected"
            /\ UNCHANGED token_status
    /\ UNCHANGED <<user_balance, req1_state>>

\* Запрос 2: начисление бонуса и погашение токена (Time-of-Use)
Req2_Redeem ==
    /\ req2_state = "authorized"
    /\ user_balance' = user_balance + 500
    /\ token_status' = "USED"
    /\ req2_state' = "success"
    /\ UNCHANGED req1_state

\* Завершение обоих запросов
Done ==
    /\ req1_state \in {"success", "rejected"}
    /\ req2_state \in {"success", "rejected"}
    /\ UNCHANGED vars

Next ==
    \/ Req1_Check
    \/ Req1_Redeem
    \/ Req2_Check
    \/ Req2_Redeem
    \/ Done

-----------------------------------------------------------------------------
\* ИНВАРИАНТ БЕЗОПАСНОСТИ:
\* Одноразовый токен на 500 бонусов НИКОГДА не должен дать пользователю > 500!
MaxOneRedemption ==
    user_balance <= 500

=============================================================================
