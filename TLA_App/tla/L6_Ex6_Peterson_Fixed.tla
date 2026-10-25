------------------------ MODULE L6_Ex6_Peterson_Fixed ------------------------
(***************************************************************************)
(* Лекция 6. Пример 6 (правильный). Алгоритм Петерсона (1981).             *)
(* Объединяет флаги (попытка 2) и очередь turn (попытка 3).                *)
(*                                                                         *)
(*   flag[me] = true;                         // 1. я хочу войти           *)
(*   turn = other;                            // 2. «проходи первым»       *)
(*   while (flag[other] && turn == other) { } // 3. жду, пока он хочет     *)
(*                                            //    И сейчас его очередь   *)
(*   ... критическая секция ...                                            *)
(*   flag[me] = false;                        // 4. больше не хочу         *)
(*                                                                         *)
(* Ожидание: 0 ошибок. Нет нарушения ME, нет deadlock, даже если сосед     *)
(* ушёл навсегда (Quit).                                                   *)
(***************************************************************************)
EXTENDS FiniteSets

CONSTANT Procs
ASSUME Cardinality(Procs) = 2

Other(p) == CHOOSE q \in Procs : q # p

VARIABLES
    flag,                       \* flag[p] : p хочет войти
    turn,                       \* кому уступили
    pc                          \* pc[p] : "idle" | "set_turn" | "wait" | "cs" | "done"

vars == <<flag, turn, pc>>

TypeOK ==
    /\ flag \in [Procs -> BOOLEAN]
    /\ turn \in Procs
    /\ pc   \in [Procs -> {"idle", "set_turn", "wait", "cs", "done"}]

Init ==
    /\ flag = [p \in Procs |-> FALSE]
    /\ turn \in Procs
    /\ pc   = [p \in Procs |-> "idle"]

\* Строка 1: flag[me] = true
SetFlag(p) ==
    /\ pc[p] = "idle"
    /\ flag' = [flag EXCEPT ![p] = TRUE]
    /\ pc'   = [pc   EXCEPT ![p] = "set_turn"]
    /\ UNCHANGED turn

\* Строка 2: turn = other
SetTurn(p) ==
    /\ pc[p] = "set_turn"
    /\ turn' = Other(p)
    /\ pc'   = [pc EXCEPT ![p] = "wait"]
    /\ UNCHANGED flag

\* Строка 3: выйти из while, когда (flag[other] = FALSE) ИЛИ (turn = me)
Enter(p) ==
    /\ pc[p] = "wait"
    /\ (flag[Other(p)] = FALSE \/ turn = p)
    /\ pc' = [pc EXCEPT ![p] = "cs"]
    /\ UNCHANGED <<flag, turn>>

\* Строка 4: flag[me] = false
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
    \/ \E p \in Procs : SetFlag(p) \/ SetTurn(p) \/ Enter(p) \/ Exit(p) \/ Quit(p)
    \/ Terminating

-----------------------------------------------------------------------------
MutualExclusion ==
    \A p, q \in Procs : (p # q) => ~(pc[p] = "cs" /\ pc[q] = "cs")

=============================================================================
