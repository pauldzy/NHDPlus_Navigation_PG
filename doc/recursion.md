## PostgreSQL Recursion

[Recursion in PostgreSQL](https://www.postgresql.org/docs/10/queries-with.html) allows very fast evaluation of iterative hierarchical queries.  As such it really returns results surprisingly fast.  However one tradeoff for the speed is that the logic is quite simplistic.  In some circumstance of complex hierarches - such as stream networks - this can results in poor performance and scaling.

A PostgreSQL recursive CT query moves depth first through the dataset as single transaction.
![Simple Recursion](/doc/simple_recursion.png)

Such that the logic will pull A, B, C, D, E, F, G, H, I, J, K and L.  Using a running array one can prevent cycling in the query. 

But when the graph folds back upon itself as in braided streams, PostgreSQL recursive logic will by necessity spawn a repetitive path upstream for each braid.  
![Braided Recursion](/doc/braided_recursion.png)

So in this case the recursion would pull A, B, C, D, E, F, G, H, I, J, K, L, M, E, F, G, H, I, J, K and L.  These duplicates are easily removed in the base of the SQL query but they are marshalled in memory during the transaction.  If you imagine traversing up the entirity of Mississippi river basin that means each small braid in the river outside New Orleans results in a total traversal of the upstream river system. Your database will simply run out of memory. 
