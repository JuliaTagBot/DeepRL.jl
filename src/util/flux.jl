
module FluxUtils

using Flux
using Flux.Tracker
using Random
# import Reproduce: ArgParseSettings, @add_arg_table



glorot_uniform(rng::Random.AbstractRNG, T::Type, dims...) = (rand(rng, T, dims...) .- 0.5f0) .* sqrt(24.0f0/sum(dims))
glorot_normal(rng::Random.AbstractRNG, T::Type, dims...) = randn(rng, T, dims...) .* sqrt(2.0f0/sum(dims))

glorot_uniform(rng::Random.AbstractRNG, dims::Vararg{Int64}) = (rand(rng, Float32, dims...) .- 0.5f0) .* sqrt(24.0f0/sum(dims))
glorot_normal(rng::Random.AbstractRNG, dims...) = randn(rng, Float32, dims...) .* sqrt(2.0f0/sum(dims))


function get_activations(model::M, data) where {M<:Flux.Chain}
    # Assume it is a chain of things
    activations = [data]
    for (idx, layer) in enumerate(model)
        push!(activations, layer(activations[idx]))
    end
    return activations
end


struct ConcatStreams{M1, M2}
    m1::M1
    m2::M2
end

Flux.@treelike ConcatStreams
(l::ConcatStreams)(x) = vcat(l.m1(x), l.m2(x))

function Base.show(io::IO, l::ConcatStreams)
  print(io, "ConcatStreams(", string(l.m1), ", ", string(l.m2), ")")
end


end
