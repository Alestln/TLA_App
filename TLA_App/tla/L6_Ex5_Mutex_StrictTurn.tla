---------------------- MODULE L6_Ex5_Mutex_StrictTurn ----------------------
(***************************************************************************)
(* Лекция 6. Пример 5. Попытка №3: строгая очередь «по талончику» turn.    *)
(*                                                                         *)
(*   while (turn != me) { }    // жду своей очереди                        *)
(*   ... критическая секция ...                                            *)
(*   turn = other;             // передаю очередь соседу                   *)
(*                                                                         *)
(* Ожидание: MutualExclusion СОБЛЮДЁН, но если один процесс больше не      *)
(* хочет входить (завершился / упал — действие Quit), второй ждёт вечно.   *)
(* TLC сообщает "Deadlock reached". Это ГОЛОДАНИЕ (starvation).            *)
(***************************************************************************)
EXTENDS FiniteSets

CONSTANT Procs
ASSUME Cardinality(Procs) = 2           \* алгоритм рассчитан ровно на двоих

Other(p) == CHOOSE q \in Procs : q # p  \* «второй» процесс

VARIABLES
    turn,                               \* чья сейчас очередь
    pc                                  \* pc[p] : "idle" | "wait" | "cs" | "done"

vars == <<turn, pc>>

TypeOK ==
    /\ turn \in Procs
    /\ pc   \in [Procs -> {"idle", "wait", "cs", "done"}]

Init ==
    /\ turn \in Procs                   \* НЕДЕТЕРМИНИЗМ: TLC проверит оба варианта
    /\ pc = [p \in Procs |-> "idle"]

Want(p) ==
    /\ pc[p] = "idle"
    /\ pc' = [pc EXCEPT ![p] = "wait"]
    /\ UNCHANGED turn

Enter(p) ==
    /\ pc[p] = "wait"
    /\ turn = p                         \* вхожу только в свою очередь
    /\ pc' = [pc EXCEPT ![p] = "cs"]
    /\ UNCHANGED turn

Exit(p) ==
    /\ pc[p] = "cs"
    /\ turn' = Other(p)                 \* отдаю очередь соседу
    /\ pc'   = [pc EXCEPT ![p] = "idle"]

\* Процесс закончил работу и больше никогда не попросит КС
Quit(p) ==
    /\ pc[p] = "idle"
    /\ pc' = [pc EXCEPT ![p] = "done"]
    /\ UNCHANGED turn

Finished    == \A p \in Procs : pc[p] = "done"
Terminating == Finished /\ UNCHANGED vars

Next ==
    \/ \E p \in Procs : Want(p) \/ Enter(p) \/ Exit(p) \/ Quit(p)
    \/ Terminating

-----------------------------------------------------------------------------
MutualExclusion ==
    \A p, q \in Procs : (p # q) => ~(pc[p] = "cs" /\ pc[q] = "cs")

=============================================================================
