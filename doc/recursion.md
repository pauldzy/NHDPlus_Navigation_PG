## PostgreSQL Recursion

[Recursion in PostgreSQL](https://www.postgresql.org/docs/10/queries-with.html) allows very fast evaluation of iterative hierarchical queries.  As such it really returns results surprisingly quick.  However one tradeoff for the speed is that the logic is quite simplistic.  In the circumstance of complex hierarches - such as stream networks - this can results in poor performance and scaling.

A PostgreSQL recursive CT query moves depth first through the dataset as single transaction.
![Simple Recursion](/doc/simple_recursion.png)

Such that the logic will pull A, B, C, D, E, F, G, H, I, J, K and L. 

But when the graph folds back upon itself as in braided streams, PostgreSQL recursive logic will by necessity spawn a repetitive path upstream for each braid.  
![Braided Recursion](/doc/braided_recursion.png)

So in this case the CTE recursion would pull A, B, C, D, E, F, G, H, I, J, K, L, M, E, F, G, H, I, J, K and L.  These duplicates are easily removed in the base of the SQL query but they are all marshalled in memory during the transaction.  If you imagine traversing up the entirity of the Mississippi river basin that means each small braid in the river outside New Orleans results in a unique traversal of the entire upstream river system. Your database session will simply run out of memory. 

I don't have a easy solution for the above problem short of keeping recursive queries to a size that works with available memory (generally around 10,000 flowlines).  I have tried emulating the recursive logic in PL/pgSQL to add more logic and it works swell, though about ten times slower than native recursion.  I suspect the solution is the same as that undertaken by the pgRouting project, code our own custom query engine in C as a PostgreSQL extension.
