-------------------- MODULE L7_Ex3_Peterson_Liveness --------------------
(***************************************************************************)
(* Лекция 7. Пример 3б. Алгоритм Петерсона (из лекции 6) — проверяем       *)
(* теперь не только Safety, но и Liveness.                                 *)
(*                                                                         *)
(*   flag[me] = true;                         // SetFlag   idle -> set_turn*)
(*   turn = other;                            // SetTurn   set_turn -> wait*)
(*   while (flag[other] && turn == other) {}  // Enter     wait -> cs      *)
(*   ... критическая секция ...                                            *)
(*   flag[me] = false;                        // Exit      cs -> idle      *)
(*                                                                         *)
(* Переменная turn — «арбитр»: при конфликте она ВСЕГДА указывает на       *)
(* одного победителя, поэтому вечной взаимной вежливости быть не может.    *)
(*                                                                         *)
(* Ожидание: 0 ошибок. Выполняются MutualExclusion, Progress и даже        *)
(* NoStarvation — при одной лишь СЛАБОЙ справедливости.                    *)
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
    /\ pc   \in [Procs -> {"idle", "set_turn", "wait", "cs"}]

Init ==
    /\ flag = [p \in Procs |-> FALSE]
    /\ turn \in Procs
    /\ pc   = [p \in Procs |-> "idle"]

SetFlag(p) ==
    /\ pc[p] = "idle"
    /\ flag' = [flag EXCEPT ![p] = TRUE]
    /\ pc'   = [pc   EXCEPT ![p] = "set_turn"]
    /\ UNCHANGED turn

SetTurn(p) ==
    /\ pc[p] = "set_turn"
    /\ turn' = Other(p)
    /\ pc'   = [pc EXCEPT ![p] = "wait"]
    /\ UNCHANGED flag

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

Next == \E p \in Procs : SetFlag(p) \/ SetTurn(p) \/ Enter(p) \/ Exit(p)

Fairness ==
    \A p \in Procs : WF_vars(SetTurn(p)) /\ WF_vars(Enter(p)) /\ WF_vars(Exit(p))

Spec == Init /\ [][Next]_vars /\ Fairness

-----------------------------------------------------------------------------
MutualExclusion ==
    \A p, q \in Procs : (p # q) => ~(pc[p] = "cs" /\ pc[q] = "cs")

Trying(p) == pc[p] \in {"set_turn", "wait"}

Progress     == (\E p \in Procs : Trying(p)) ~> (\E p \in Procs : pc[p] = "cs")
NoStarvation == \A p \in Procs : Trying(p) ~> (pc[p] = "cs")

=============================================================================

