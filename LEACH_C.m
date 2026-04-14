clc;
clear;
close all;

%% Parameters
numNodes = 100;         % Number of sensor nodes
numRounds = 2000;        % Number of rounds
numCHs = 10;            % Fixed number of cluster heads (CHs) per round
dim = 100;              % Size of the area (100x100 grid)
initialEnergy = 0.5;    % Initial energy of each node (in Joules)
sink = [50, 175];       % Sink node position (Base Station)

% Energy parameters
Eelec = 50e-9;          % Energy to run transmitter/receiver electronics (J/bit)
Efs = 10e-12;           % Free-Space model energy (J/bit/m^2)
Emp = 0.0013e-12;       % Multi-Path model energy (J/bit/m^4)
Eagg = 5e-9;            % Data aggregation energy for CH (J/bit)
packetSize = 4800;      % Packet size (in bits)
d0 = sqrt(Efs/Emp);     % Threshold distance

%% Node Initialization
nodes = struct();
for i = 1:numNodes
    nodes(i).x = rand() * dim;  % X-coordinate
    nodes(i).y = rand() * dim;  % Y-coordinate
    nodes(i).energy = initialEnergy;  % Initial energy
    nodes(i).alive = true;  % Alive status
end

totalEnergy = zeros(1, numRounds);  % Track total energy
aliveNodes = zeros(1, numRounds);   % Track number of alive nodes
energyConsumptionPerRound = zeros(1, numRounds); % Track energy consumption per round

%% Main Loop - LEACH-C (Centralized Cluster Head Selection)
for round = 1:numRounds
    energyBeforeRound = sum([nodes.energy]);  % Total energy before round
    
    % Step 1: Centralized Selection of Cluster Heads
    % The sink selects cluster heads based on nodes' remaining energy and position
    aliveNodesIdx = find([nodes.alive]);
    if length(aliveNodesIdx) < numCHs
        break; % Not enough nodes to select cluster heads
    end
    % Sort nodes by their remaining energy
    [~, sortedEnergyIdx] = sort([nodes(aliveNodesIdx).energy], 'descend');
    selectedCHs = aliveNodesIdx(sortedEnergyIdx(1:numCHs));  % Select top numCHs nodes
    
    % Step 2: Form Clusters
    clusters = cell(numCHs, 1);
    for i = 1:numNodes
        if nodes(i).alive && ~ismember(i, selectedCHs)  % Not a CH
            distances = zeros(1, numCHs);
            for ch = 1:numCHs
                distances(ch) = sqrt((nodes(i).x - nodes(selectedCHs(ch)).x)^2 + (nodes(i).y - nodes(selectedCHs(ch)).y)^2);
            end
            [~, closestCH] = min(distances);  % Find closest CH
            clusters{closestCH} = [clusters{closestCH}, i];  % Add node to cluster
        end
    end
    
    % Step 3: Energy Consumption
    for ch = 1:numCHs
        % Cluster members' energy consumption for sending data to CH
        if ~isempty(clusters{ch})
            for member = clusters{ch}
                distToCH = sqrt((nodes(member).x - nodes(selectedCHs(ch)).x)^2 + (nodes(member).y - nodes(selectedCHs(ch)).y)^2);
                if distToCH < d0
                    memberEnergy = (packetSize * Eelec) + (packetSize * Efs * distToCH^2);  % Free-space model
                else
                    memberEnergy = (packetSize * Eelec) + (packetSize * Emp * distToCH^4);  % Multi-path model
                end
                nodes(member).energy = nodes(member).energy - memberEnergy;
                if nodes(member).energy <= 0
                    nodes(member).alive = false;
                end
            end
        end
        
        % CH energy consumption for receiving data from cluster members
        numMembersInCluster = length(clusters{ch});
        CHReceivingEnergy = numMembersInCluster * packetSize * Eelec;  % Receiving energy for CH
        nodes(selectedCHs(ch)).energy = nodes(selectedCHs(ch)).energy - CHReceivingEnergy;
        
        % CH energy consumption for data aggregation
        CHAggregationEnergy = numMembersInCluster * packetSize * Eagg;  % Aggregation energy for CH
        nodes(selectedCHs(ch)).energy = nodes(selectedCHs(ch)).energy - CHAggregationEnergy;
        
        % CH energy consumption for sending data to the sink
        distToSink = sqrt((nodes(selectedCHs(ch)).x - sink(1))^2 + (nodes(selectedCHs(ch)).y - sink(2))^2);
        if distToSink < d0
            CHTransmissionEnergy = (packetSize * Eelec) + (packetSize * Efs * distToSink^2);  % Free-space model
        else
            CHTransmissionEnergy = (packetSize * Eelec) + (packetSize * Emp * distToSink^4);  % Multi-path model
        end
        nodes(selectedCHs(ch)).energy = nodes(selectedCHs(ch)).energy - CHTransmissionEnergy;
        
        if nodes(selectedCHs(ch)).energy <= 0
            nodes(selectedCHs(ch)).alive = false;
        end
    end
    
    % Track energy and alive nodes
    totalEnergy(round) = sum([nodes.energy]);  % Total energy after the round
    energyConsumptionPerRound(round) = energyBeforeRound - totalEnergy(round);  % Energy consumed during the round
    aliveNodes(round) = sum([nodes.alive]);  % Number of alive nodes after the round
    
    % Display progress
    fprintf('Round: %d, Alive Nodes: %d, Total Energy: %.4f J\n', round, aliveNodes(round), totalEnergy(round));
end

%% Save Results to Excel
resultTable = table((1:numRounds)', aliveNodes(1:numRounds)', energyConsumptionPerRound(1:numRounds)', totalEnergy(1:numRounds)', ...
    'VariableNames', {'Round', 'AliveNodes', 'EnergyConsumptionPerRound', 'TotalRemainingEnergy'});

filename = 'LEACH_C_Results_with_CH_Aggregation.xlsx';
writetable(resultTable, filename);

disp(['Results saved to ', filename]);

%% Plot Results
figure;
subplot(2, 1, 1);
plot(1:numRounds, aliveNodes(1:numRounds), 'b-', 'LineWidth', 2);
title('Number of Alive Nodes per Round');
xlabel('Round');
ylabel('Alive Nodes');
grid on;

subplot(2, 1, 2);
plot(1:numRounds, totalEnergy(1:numRounds), 'r-', 'LineWidth', 2);
title('Total Energy Consumption per Round');
xlabel('Round');
ylabel('Total Energy (J)');
grid on;
