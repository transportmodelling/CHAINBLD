# CHAINBLD
A multimodal transport chain builder, taking the unimodal level of service matrices as its input.

Each mode of transport is represented by a character. Each chain type is represented by a string, the consecutive characters of which represent the transport modes of the consecutive transport chain legs.

# Algorithm
The algorithm used to generate the transport chains is a one-to-many algorithm, that generates the chains from one origin to all destinations, for all chain types. As a preparation step the list of chain types that we want to generate the chains for is extended, such that for each chain type in the list its sub chain type (that is the chain type obtained by removing the last chain leg) is also included in the list, preceding the chain type itself.

For a fixed origin, we iterate over all chain types, determining the best chains to all destinations for each chain type. For single leg chain types the best chains to all destinations simply follow from the input level of service. For chain types consisting of more than one leg, we take the best chains of its sub chain type as a starting point. These are available as the sub chain type precedes the chain type itself in the extended list of chain types.

# Dependencies
Before you can compile this program, you will need to clone the https://github.com/transportmodelling/Utils and https://github.com/transportmodelling/matio repositories, and then add it to your Delphi Library path.
