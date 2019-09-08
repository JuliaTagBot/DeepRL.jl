import JuliaRL

using Plots

import ArcadeLearningEnvironment
const ALE = ArcadeLearningEnvironment


"""
    Atari

An interface adapted from https://github.com/JuliaML/AtariAlgos.jl/blob/master/src/AtariAlgos.jl with a backend 
implemented by https://github.com/JuliaReinforcementLearning/ArcadeLearningEnvironment.jl. Because we want to have
some better fidelity with settings, reimplementing is easier than writting a wrapper around a wrapper around a wrapper...
"""
mutable struct Atari <: JuliaRL.AbstractEnvironment
    ale::ALE.ALEPtr
    lives::Int
    died::Bool
    reward::Float64
    score::Float64
    nframes::Int
    width::Int
    height::Int
    rawscreen::Vector{Cuchar}  # raw screen data from the most recent frame
    state::Vector{Float64}  # the game state... raw screen data converted to Float64
    screen::Matrix{RGB{Float64}}

    function Atari(gamename::AbstractString)
        ale = ALE.ALE_new()
        ALE.loadROM(ale, gamename)
        w = ALE.getScreenWidth(ale)
        h = ALE.getScreenHeight(ale)
        rawscreen = Array{Cuchar}(undef, w * h * 3)
        state = similar(rawscreen, Float64)
        screen = fill(RGB{Float64}(0,0,0), h, w)
        new(ale, 0, false, 0., 0., 0, w, h, rawscreen, state, screen)
    end
end

function Base.close(env::Atari)
    env.state = typeof(env.state)()
    ALE.ALE_del(env.ale)
end

JuliaRL.get_actions(env::Atari) = ALE.getLegalActionSet(env.ale)
valid_action(env::Atari, action) = action in JuliaRL.get_actions(env)


function update_screen(env::Atari)
    idx = 1
    for i in 1:env.height, j in 1:env.width
        env.screen[i,j] = RGB{Float64}(env.state[idx], env.state[idx+1], env.state[idx+2])
        idx += 3
    end
    env.screen
end

@recipe function f(env::Atari)
    ticks := nothing
    foreground_color_border := nothing
    grid := false
    legend := false
    aspect_ratio := 1

    # convert to Image
    update_screen(env)
end

function update_state(env::Atari)
    # get the raw screen data
    ALE.getScreenRGB!(env.ale, env.rawscreen)
    for i in eachindex(env.rawscreen)
        env.state[i] = env.rawscreen[i] / 256
    end
    env.lives = ALE.lives(env.ale)
end

# Set seed default to 0
function JuliaRL.reset!(env::Atari; seed::Int64=0, kwargs...)
    ALE.reset_game(env.ale)
    ALE.setInt(env.ale, "random_seed", seed)
    env.lives = 0
    env.died = false
    env.reward = 0
    env.score = 0
    env.nframes = 0
    update_state(env)

    return
end

function JuliaRL.environment_step!(env::Atari, action; kwargs...)
    # act and get the reward and new state
    env.reward = ALE.act(env.ale, action)
    env.score += env.reward
    update_state(env)
    return
end

JuliaRL.get_reward(env::Atari) = env.reward 
JuliaRL.is_terminal(env::Atari) = ALE.game_over(env.ale)
JuliaRL.get_state(env::Atari) = env.state