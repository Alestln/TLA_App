------------------------- MODULE Ex3_BankAtm_Buggy -------------------------
(***************************************************************************)
(* Пример 3 (Ошибочный вариант). Банкомат и двойное списание (TOCTOU).     *)
(* Баланс: 100 грн. Два банкомата запрашивают по 80 грн.                   *)
(* Баг: проверка баланса и списание разделены во времени.                  *)
(* Итог: оба проверяют 100 >= 80, оба списывают, баланс становится -60 грн.*)
(***************************************************************************)
EXTENDS Integers

VARIABLES 
    balance,    \* Баланс счёта
    atm1,       \* Состояние банкомата 1: "idle", "authorized", "done", "rejected"
    atm2        \* Состояние банкомата 2: "idle", "authorized", "done", "rejected"

vars == <<balance, atm1, atm2>>

Init ==
    /\ balance = 100
    /\ atm1 = "idle"
    /\ atm2 = "idle"

\* ATM 1 проверяет баланс: разрешено (Time-of-Check)
Atm1_Check ==
    /\ atm1 = "idle"
    /\ balance >= 80
    /\ atm1' = "authorized"
    /\ UNCHANGED <<balance, atm2>>  \* Баланс ЕЩЁ НЕ списан!

\* ATM 1 проверяет баланс: отказ
Atm1_Reject ==
    /\ atm1 = "idle"
    /\ balance < 80
    /\ atm1' = "rejected"
    /\ UNCHANGED <<balance, atm2>>

\* ATM 1 выдаёт наличные (Time-of-Use)
Atm1_Withdraw ==
    /\ atm1 = "authorized"
    /\ balance' = balance - 80
    /\ atm1' = "done"
    /\ UNCHANGED atm2

\* ATM 2 проверяет баланс: разрешено (Time-of-Check)
Atm2_Check ==
    /\ atm2 = "idle"
    /\ balance >= 80
    /\ atm2' = "authorized"
    /\ UNCHANGED <<balance, atm1>>  \* Баланс ЕЩЁ НЕ списан!

\* ATM 2 проверяет баланс: отказ
Atm2_Reject ==
    /\ atm2 = "idle"
    /\ balance < 80
    /\ atm2' = "rejected"
    /\ UNCHANGED <<balance, atm1>>

\* ATM 2 выдаёт наличные (Time-of-Use)
Atm2_Withdraw ==
    /\ atm2 = "authorized"
    /\ balance' = balance - 80
    /\ atm2' = "done"
    /\ UNCHANGED atm1

\* Завершение работы
Done ==
    /\ atm1 \in {"done", "rejected"}
    /\ atm2 \in {"done", "rejected"}
    /\ UNCHANGED vars

Next ==
    \/ Atm1_Check
    \/ Atm1_Reject
    \/ Atm1_Withdraw
    \/ Atm2_Check
    \/ Atm2_Reject
    \/ Atm2_Withdraw
    \/ Done

-----------------------------------------------------------------------------
\* ИНВАРИАНТ БЕЗОПАСНОСТИ:
\* Баланс счёта НИКОГДА не должен уходить в минус!
NoOverdraft ==
    balance >= 0

=============================================================================
