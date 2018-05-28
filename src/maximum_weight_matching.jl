"""
maximum_weight_matching{T <:Real}(g::Graph, w::Dict{Edge,T} = Dict{Edge,Int64}())

Given a graph `g` and an edgemap `w` containing weights associated to edges,
returns a matching with the maximum total weight.
`w` is a dictionary that maps edges i => j to weights.
If no weight parameter is given, all edges will be considered to have weight 1
(results in max cardinality matching)

The efficiency of the algorithm depends on the input graph:
  - If the graph is bipartite, then the LP relaxation is integral.
  - If the graph is not bipartite, then it requires a MIP solver and
  the computation time may grow exponentially.

The package JuMP.jl and one of its supported solvers is required.

Returns MatchingResult containing:
  - a solve status (indicating whether the problem was solved to optimality)
  - the optimal cost
  - a list of each vertex's match (or -1 for unmatched vertices)
"""
function maximum_weight_matching end

function maximum_weight_matching(g::Graph,
          solver::AbstractMathProgSolver,
          w::AbstractMatrix{T} = default_weights(g)) where {T <:Real}

    model = Model(solver = solver)
    n = nv(g)
    edge_list = collect(edges(g))

    # put the edge weights in w in the right order to be compatible with edge_list
    for j in 1:n
      for i in 1:n
        if i > j  && w[i,j] > zero(T) && w[j,i] < w[i,j]
          w[j,i] = w[i,j]
        end
        if Edge(i,j) ∉ edge_list
          w[i,j] = zero(T)
        end
      end
    end
    
    if is_bipartite(g)
      @variable(model, x[edge_list] >= 0) # no need to enforce integrality
    else
      @variable(model, x[edge_list] >= 0, Int) # requires MIP solver
    end
    @objective(model, Max, sum(x[e]*w[src(e),dst(e)] for e in edge_list))
    @constraint(model, c1[i=1:n],
                sum(x[Edge(i,j)] for j=filter(l -> l > i, neighbors(g,i))) +
                sum(x[Edge(j,i)] for j=filter(l -> l <= i, neighbors(g,i)))
                <= 1)

    status = solve(model)
    solution = getvalue(x)
    cost = getobjectivevalue(model)
    ## TODO: add the option of returning the solve status as part of the MatchingResult type.
    return MatchingResult(cost, dict_to_arr(n, solution))
end

""" Returns an array of mates from a dictionary that maps edges to {0,1} """
function dict_to_arr(n::Int64, solution::JuMP.JuMPArray{T,1,Tuple{Array{E,1}}}) where {T<: Real, E<: Edge}
  mate = fill(-1,n)
  for i in keys(solution)
    key = i[1] # i is a tuple with 1 element.
    if solution[key] >= 1 - 1e-5 # Some tolerance to numerical approximations by the solver.
        mate[src(key)] = dst(key)
        mate[dst(key)] = src(key)
    end
  end
  return mate
end


function default_weights(g::G) where {G<:AbstractGraph}
  m = spzeros(nv(g),nv(g))
  for e in edges(g)
    m[src(e),dst(e)] = 1
  end
  return m
end