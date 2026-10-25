------------------------ MODULE L6_Ex6_Peterson_Buggy ------------------------
(***************************************************************************)
(* Лекция 6. Пример 6 (ошибочный). Петерсон, в котором переставили         *)
(* ДВЕ СТРОКИ местами: сначала turn, потом flag.                           *)
(*                                                                         *)
(*   turn = other;                            // 1. (было вторым!)         *)
(*   flag[me] = true;                         // 2. (было первым!)         *)
(*   while (flag[other] && turn == other) { }                              *)
(*                                                                         *)
(* Ожидание: MutualExclusion НАРУШЕН. Порядок строк — часть алгоритма.     *)
(***************************************************************************)
EXTENDS FiniteSets

CONSTANT Procs
ASSUME Cardinality(Procs) = 2

Other(p) == CHOOSE q \in Procs : q # p

VARIABLES flag, turn, pc
vars == <<flag, turn, pc>>

TypeOK ==
    /\ flag \in [Procs -> BOOLEAN]
    /\ turn \in Procs
    /\ pc   \in [Procs -> {"idle", "set_flag", "wait", "cs", "done"}]

Init ==
    /\ flag = [p \in Procs |-> FALSE]
    /\ turn \in Procs
    /\ pc   = [p \in Procs |-> "idle"]

\* Строка 1 (переставлена!): turn = other
SetTurn(p) ==
    /\ pc[p] = "idle"
    /\ turn' = Other(p)
    /\ pc'   = [pc EXCEPT ![p] = "set_flag"]
    /\ UNCHANGED flag

\* Строка 2 (переставлена!): flag[me] = true
SetFlag(p) ==
    /\ pc[p] = "set_flag"
    /\ flag' = [flag EXCEPT ![p] = TRUE]
    /\ pc'   = [pc   EXCEPT ![p] = "wait"]
    /\ UNCHANGED turn

Enter(p) ==
    /\ pc[p] = "wait"
    /\ (flag[Other(p)] = FALSE \/ turn = p)
    /\ pc' = [pc EXCEPT ![p] = "cs"]
    /\ UNCHANGED <<flag, turn>>

Exit(p) ==
    /\ pc[p] = "cs"
    /\ flag' = [flag EXCEPT ![p] = FALSE]
    /\ pc'   = [pc   EXCEPT ![p] = "idle"]
    /\ UNCHANGED turn

Quit(p) ==
    /\ pc[p] = "idle"
    /\ pc' = [pc EXCEPT ![p] = "done"]
    /\ UNCHANGED <<flag, turn>>

Finished    == \A p \in Procs : pc[p] = "done"
Terminating == Finished /\ UNCHANGED vars

Next ==
    \/ \E p \in Procs : SetTurn(p) \/ SetFlag(p) \/ Enter(p) \/ Exit(p) \/ Quit(p)
    \/ Terminating

-----------------------------------------------------------------------------
MutualExclusion ==
    \A p, q \in Procs : (p # q) => ~(pc[p] = "cs" /\ pc[q] = "cs")

=============================================================================
