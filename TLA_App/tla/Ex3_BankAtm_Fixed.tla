------------------------- MODULE Ex3_BankAtm_Fixed -------------------------
(***************************************************************************)
(* Пример 3 (Исправленный вариант). Банкомат с атомарным списанием.        *)
(* Проверка баланса и списание объединены в один атомарный шаг (транзакция)*)
(* либо второй банкомат получает отказ (rejected).                         *)
(***************************************************************************)
EXTENDS Integers

VARIABLES 
    balance,    \* Баланс счёта
    atm1,       \* Состояние банкомата 1: "idle", "done", "rejected"
    atm2        \* Состояние банкомата 2: "idle", "done", "rejected"

vars == <<balance, atm1, atm2>>

Init ==
    /\ balance = 100
    /\ atm1 = "idle"
    /\ atm2 = "idle"

\* ATM 1 пытается снять 80 грн: атомарная транзакция (UPDATE ... WHERE balance >= 80)
Atm1_Withdraw ==
    /\ atm1 = "idle"
    /\ IF balance >= 80
       THEN /\ balance' = balance - 80
            /\ atm1' = "done"
       ELSE /\ atm1' = "rejected"
            /\ UNCHANGED balance
    /\ UNCHANGED atm2

\* ATM 2 пытается снять 80 грн: атомарная транзакция (UPDATE ... WHERE balance >= 80)
Atm2_Withdraw ==
    /\ atm2 = "idle"
    /\ IF balance >= 80
       THEN /\ balance' = balance - 80
            /\ atm2' = "done"
       ELSE /\ atm2' = "rejected"
            /\ UNCHANGED balance
    /\ UNCHANGED atm1

\* Состояние завершения (stuttering step)
Done ==
    /\ atm1 \in {"done", "rejected"}
    /\ atm2 \in {"done", "rejected"}
    /\ UNCHANGED vars

Next ==
    \/ Atm1_Withdraw
    \/ Atm2_Withdraw
    \/ Done

-----------------------------------------------------------------------------
\* ИНВАРИАНТ БЕЗОПАСНОСТИ:
\* Баланс счёта НИКОГДА не должен уходить в минус!
NoOverdraft ==
    balance >= 0

=============================================================================
