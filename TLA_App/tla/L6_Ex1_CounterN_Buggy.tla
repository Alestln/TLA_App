------------------------ MODULE L6_Ex1_CounterN_Buggy ------------------------
(***************************************************************************)
(* Лекция 6. Пример 1 (ошибочный). Счётчик из лекции 5, но для N потоков.  *)
(* Было: t1_pc, t1_reg, t2_pc, t2_reg (по переменной на каждый поток).     *)
(* Стало: pc[p], reg[p] — словари «поток -> значение».                     *)
(* Количество потоков задаётся в .cfg, код от него НЕ зависит.             *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANT Procs                  \* множество потоков, например {p1, p2, p3}

VARIABLES
    counter,                    \* общий счётчик в памяти
    pc,                         \* pc[p]  : "idle" | "read" | "done"
    reg                         \* reg[p] : локальный регистр CPU потока p

vars == <<counter, pc, reg>>
N == Cardinality(Procs)

TypeOK ==
    /\ counter \in 0..N
    /\ pc  \in [Procs -> {"idle", "read", "done"}]
    /\ reg \in [Procs -> 0..N]

Init ==
    /\ counter = 0
    /\ pc  = [p \in Procs |-> "idle"]
    /\ reg = [p \in Procs |-> 0]

\* Шаг 1 инструкции counter++ : загрузка в регистр
Read(p) ==
    /\ pc[p] = "idle"
    /\ reg' = [reg EXCEPT ![p] = counter]
    /\ pc'  = [pc  EXCEPT ![p] = "read"]
    /\ UNCHANGED counter

\* Шаг 2 инструкции counter++ : запись регистр + 1
Write(p) ==
    /\ pc[p] = "read"
    /\ counter' = reg[p] + 1
    /\ pc'      = [pc EXCEPT ![p] = "done"]
    /\ UNCHANGED reg

Finished == \A p \in Procs : pc[p] = "done"

Terminating == Finished /\ UNCHANGED vars       \* «стоим на месте», чтобы не было ложного deadlock

Next ==
    \/ \E p \in Procs : Read(p) \/ Write(p)
    \/ Terminating

-----------------------------------------------------------------------------
\* Когда все закончили, счётчик обязан равняться числу потоков
CorrectSum == Finished => counter = N

=============================================================================
