
"""
Summary of posterior over (f, f′) given current evaluations. The posterior
takes the form of a GP, which can be queried using methods #TODO, and stores
the evaluations so far.
"""
mutable struct PLSPosterior{T <: AbstractFloat}
    Ts::Vector{T}
    Y::Vector{T}
    ∇Y::Vector{T}
    σ²_f::T
    σ²_∇::T
    G::Matrix{T}   # posterior kernel matrix
    A::Matrix{T}   # posterior mean weights
end

# Constructor
function PLSPosterior(Ts::Vector{T}, Y::Vector{T}, ∇Y::Vector{T}, σ²_f::T, σ²_∇::T; ζ=10) where T <: AbstractFloat

    N = length(Ts)

    # build prior Gram matrix components
    K   = k.(Ts, Ts')
    K∂  = kd.(Ts, Ts')
    ∂K∂ = dkd.(Ts, Ts')

    # build full (noised) Gram matrix
    G = [K, K∂; transpose(K∂), ∂K∂];
    G[diagind(G)[1:N]] += σ²_f
    G[diagind(G)[N+1:2N]] += σ²_∇

    # weights of posterior mean (for linear combo of query points)
    A = G \ [Y; ∇Y];

    return PLSPosterior(Ts, Y, ∇Y, σ²_f, σ²_∇, G, A)
end


#= Integrated Wiener Process Kernel functions (function and derivative)
------------------------------------------------------------------------=#
# kernel:
k(a,b)   = min(a + ζ,b + ζ)^3/3 + 0.5 * abs(a-b) * min(a + ζ,b + ζ)^2;
kd(a,b)  = (a<b) * ((a + ζ)^2/2) + (a>=b) * ((a + ζ)*(b + ζ) - 0.5 * (b + ζ)^2);
dk(a,b)  = (a>b) * ((b+ζ)^2/2) + (a<=b) .* ((a+ζ)*(b+ζ) - 0.5 .* (a+ζ).^2);
dkd(a,b) = min(a+ζ,b+ζ);

# further derivatives
ddk(a,b) = (a<=b) * (b-a);
ddkd(a,b) = (a<=b);
dddk(a,b) = -(a<=b);


#= Posterior statistic calculations for PLSPosterior
------------------------------------------------------------------------=#
# posterior mean function and all its derivatives
m(Post::PLSPosterior, t)   = [k.(t, Ts')    kd.(t,  Ts')  ] * Post.A;
d1m(Post::PLSPosterior, t) = [dk.(t, Ts')   dkd.(t,  Ts') ] * Post.A;
d2m(Post::PLSPosterior, t) = [ddk.(t, Ts')  ddkd.(t,  Ts')] * Post.A;
d3m(Post::PLSPosterior{T}, t) where T <: AbstractFloat = [dddk.(t, Ts')  zeros(T, 1, N)] * Post.A;

# posterior marginal covariance between function and first derivative
V(Post::PLSPosterior, t)   = k(t,t)   - ([k(t, Ts')   kd(t, Ts') ] * (Post.G \ [k(t, Ts')   kd(t, Ts') ]'));
Vd(Post::PLSPosterior, t)  = kd(t,t)  - ([k(t, Ts')   kd(t, Ts') ] * (Post.G \ [dk(t, Ts')  dkd(t, Ts')]'));
dVd(Post::PLSPosterior, t) = dkd(t,t) - ([dk(t, Ts')  dkd(t, Ts')] * (Post.G \ [dk(t, Ts')  dkd(t, Ts')]'));


# covariance terms with function (derivative) values at origin
V0f(Post::PLSPosterior, t)   = k(0,t)   - ([k(0, Ts')   kd(0, Ts') ] * (Post.G \ [k(t, Ts')   kd(t, Ts') ]'));
Vd0f(Post::PLSPosterior, t)  = dk(0,t)  - ([dk(0, Ts')  dkd(0, Ts')] * (Post.G \ [k(t, Ts')   kd(t, Ts') ]'));
V0df(Post::PLSPosterior, t)  = kd(0,t)  - ([k(0, Ts')   kd(0, Ts') ] * (Post.G \ [dk(t, Ts')  dkd(t, Ts')]'));  # <= Is this one really necessary?
Vd0df(Post::PLSPosterior, t) = dkd(0,t) - ([dk(0, Ts')  dkd(0, Ts')] * (Post.G \ [dk(t, Ts')  dkd(t, Ts')]'));


# Update
update!(x::PLSPosterior, T, Y, ∇Y, σ²_f, σ²_∇) = error("Not implemented yet.")

Base.length(x::PLSPosterior) = length(x.T)
