# CHAINBLD
A multimodal transport chain builder, taking the unimodal level of service matrices as its input.

Each mode of transport is represented by a character. Each chain type is represented by a string, the consecutive characters of which represent the transport modes of the consecutive transport chain legs.

# Algorithm
The algorithm used to generate the transport chains is a one-to-many algorithm, that generates the chains from one origin to all destinations, for all chain types. As a preparation step the list of chain types that we want to generate the chains for is extended, such that for each chain type in the list its sub chain type (that is the chain type obtained by removing the last chain leg) is also included in the list.

# Dependencies
Before you can compile this program, you will need to clone the https://github.com/transportmodelling/Utils and https://github.com/transportmodelling/matio repositories, and then add it to your Delphi Library path.
