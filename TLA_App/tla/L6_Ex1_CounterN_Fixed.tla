------------------------ MODULE L6_Ex1_CounterN_Fixed ------------------------
(***************************************************************************)
(* Лекция 6. Пример 1 (исправленный). Атомарный инкремент для N потоков.   *)
(* Аналог Interlocked.Increment: чтение и запись — ОДНО действие.          *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANT Procs

VARIABLES
    counter,                    \* общий счётчик
    pc                          \* pc[p] : "idle" | "done"

vars == <<counter, pc>>
N == Cardinality(Procs)

TypeOK ==
    /\ counter \in 0..N
    /\ pc \in [Procs -> {"idle", "done"}]

Init ==
    /\ counter = 0
    /\ pc = [p \in Procs |-> "idle"]

\* Один неделимый шаг: прочитать, прибавить, записать
Inc(p) ==
    /\ pc[p] = "idle"
    /\ counter' = counter + 1
    /\ pc' = [pc EXCEPT ![p] = "done"]

Finished == \A p \in Procs : pc[p] = "done"

Terminating == Finished /\ UNCHANGED vars

Next ==
    \/ \E p \in Procs : Inc(p)
    \/ Terminating

-----------------------------------------------------------------------------
CorrectSum == Finished => counter = N

=============================================================================
