# Engineering Ingegneria Informatica S.p.A.
# This code is licensed under MIT license (see LICENSE for details)

# Overview
# In this use case, realised with AnyLogic simulation software, there are two shuttles responsible for 
# transporting materials (one material at a time) sharing the same track. 
# The materials are placed in the pallet rack and each is assigned a destination chosen from 4 destinations. 
# Once the pallet has arrived at its destination, it remains at the destination for a fixed
# time, after which the destination will be free again. The objective is to transport the materials to their 
# destinations as quickly as possible, avoiding collisions between the two shuttles and considering that
# each destination can hold a maximum of one pallet at the same time.

# The AnyLogic model and further details are available at https://github.com/FabCimmino/MaterialHandling

inkling "2.0"

using Math
using Goal

# Global observations (input state for the DRL model and variables for reward assignment and episode termination)
type SimState {
    pallet_state: number<0 .. 4 step 1>[15], # 4 if pallet i-th rack cell is empty, otherwise the number of the pallet's destination - 1
    shuttle1_start_position: number<0 .. 14 step 1>, #current position index of shuttle 1
    shuttle2_start_position: number<0 .. 14 step 1>, #current position index of shuttle 2
    destination: number<0 .. 1 step 1>[4], #0 if the i-th destination is occupied, 1 if it is free
    shuttle_is_delivering: number<-1 .. 13 step 1>[2], #-1 if the shuttle is not transporting pallets, otherwise a discrete index of the final position of the shuttle to arrive at
    distance: number<-14 .. 14 step 1>, #distance between the two shuttles (shuttle1StartPosition - shuttle2StartPosition)

    collisions: number, #0 if there was no collision in the current iteration, otherwise 1
    invalid_action: number, #0 if there were no invalid actions in the current iteration (e.g. taking a pallet from an empty cell), otherwise 1
    mission_complete: number, #1 if when the pick action is made it is collision-free, otherwise 0
    finish_simulation: number #1 when the last pallet was also brought to its destination
}


# Input state for the DRL model
type SimSubState {
    pallet_state: number<0 .. 4 step 1>[15],
    shuttle1_start_position: number<0 .. 14 step 1>,
    shuttle2_start_position: number<0 .. 14 step 1>,
    destination: number<0 .. 1 step 1>[4],
    shuttle_is_delivering: number<-1 .. 13 step 1>[2],
    distance: number<-14 .. 14 step 1>
}


# Action for each shuttle:
# 0 = no action, 1 = move to the left, 2 = move to the right, 3 = pick the pallet and transport it to its destination
type SimAction {
    action_1: number<a_0 = 0, a_1 = 1, a_2 = 2, a_3 = 3>,
    action_2: number<a_0 = 0, a_1 = 1, a_2 = 2, a_3 = 3>
}

simulator Simulator(action: SimAction): SimState {
    # Automatically launch the simulator with this
    # registered package name.
    package "MaterialHandling-sim"
}

function getReward(state: SimState) {
    # - 1.5 to finish as soon as possible
    # - state.invalid_action to penalise when there is an invalid action
    # + state.mission_complete * 10 to reward when there is collision-free pick-up action
    # - state.collisions * 10 to penalise when there is a collision
    var reward = -1.5 - state.invalid_action + state.mission_complete * 10 - state.collisions * 10
    return reward
}

function isTerminal(state: SimState) {
    return state.finish_simulation == 1
}


graph (input: SimSubState): SimAction {
    concept MoveShuttle(input): SimAction {
        curriculum {

            source Simulator
            reward getReward
            terminal isTerminal

            training {
                EpisodeIterationLimit: 150,
                NoProgressIterationLimit: 12000000,
                TotalIterationLimit: 30000000
            }
        }
    }
}

