## PostgreSQL Recursion

[Recursion in PostgreSQL](https://www.postgresql.org/docs/10/queries-with.html) allows very fast evaluation of iterative hierarchical queries.  As such it really returns results surprisingly quick.  However one tradeoff for the speed is that the logic is quite simplistic.  In the circumstance of complex hierarches - such as stream networks - this can results in poor performance and scaling.

A PostgreSQL recursive CT query moves depth first through the dataset as single transaction.

![Simple Recursion](/doc/simple_recursion.png)

Such that the logic will pull A, B, C, D, E, F, G, H, I, J, K and L. 

But when the graph folds back upon itself as in braided streams, PostgreSQL recursive logic will by necessity spawn a repetitive path upstream for each braid.  

![Braided Recursion](/doc/braided_recursion.png)

So in this case the CTE recursion would pull A, B, C, D, E, F, G, H, I, J, K, L, M, E, F, G, H, I, J, K and L.  These duplicates are easily removed in the base of the SQL query but they are all marshalled in memory during the transaction.  If you imagine traversing up the entirity of the Mississippi river basin that means each small braid in the river outside New Orleans results in a unique traversal of the entire upstream river system. Your database session will simply run out of memory.

Some observers might think this is easily prevented using a running array as done to prevent graph cycling. However that tactic only works to prevent a given traversal from encountering its own history, not other traversals and their own histories.  So perhaps to better explain the traversals in the braided example above
* A starts the query
* B came from A
* C from B from A
* D from B from A
* E from D from B from A
* F from E from D from B from A
* onward...
* M only knows it came from A
* E only knows it came from M from A
* F from E from M from A
* onward...

The two encounters of F have no way to know that the other has already traversed it.  

I don't have a easy solution for the above problem short of keeping recursive queries to a size that works with available memory (generally around 10,000 flowlines).  I have tried emulating the recursive logic in PL/pgSQL to add a brake on the duplicate traversals and it works swell, though about ten times slower than native recursion.  I suspect the solution is the same as that undertaken by the pgRouting project, code our own custom query engine in C as a PostgreSQL extension.
