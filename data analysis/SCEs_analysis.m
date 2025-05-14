function [all_num_sces, all_sce_frequency_seconds, all_avg_active_cell_SCEs, all_prop_active_cell_SCEs, all_avg_duration_ms] = SCEs_analysis(all_TRace, all_sampling_rate, all_Race, all_Raster, all_RasterRace, all_sces_distances, date_group_paths)

% Variables pour stocker les résultats
all_num_sces = zeros(length(date_group_paths), 1);  % Nombre de SCEs pour chaque groupe
all_sce_frequency_seconds = zeros(length(date_group_paths), 1);  % Fréquence des SCEs en secondes pour chaque groupe
all_avg_active_cell_SCEs = zeros(length(date_group_paths), 1);  % Moyenne du nombre de cellules actives par SCE pour chaque groupe
all_prop_active_cell_SCEs = zeros(length(date_group_paths), 1);  % Proportion des cellules actives pendant les SCEs pour chaque groupe
all_avg_duration_ms = zeros(length(date_group_paths), 1);  % Durée moyenne des SCEs en millisecondes pour chaque groupe

for m = 1:length(date_group_paths)
    try
        % Number of SCEs
        TRace = all_TRace{m};
        TRace = TRace(:);  % Assurez-vous que TRace est un vecteur colonne
        num_sces = numel(TRace);  % Nombre total de SCEs pour le groupe actuel
        
        % Fréquence des SCEs en secondes
        sampling_rate = all_sampling_rate{m};
        nb_seconds = numel(all_Raster{m}) / sampling_rate;  % Durée totale en secondes (en utilisant le nombre de frames de Raster)
        sce_frequency_seconds = num_sces / nb_seconds;  % Calcul de la fréquence des SCEs en secondes
        
        % Moyenne du nombre de cellules actives dans les SCEs
        Race = all_Race{m};
        avg_active_cell_SCEs = mean(sum(Race, 1));  % Moyenne des cellules actives pendant les SCEs
        
        % Proportion des cellules actives dans les SCEs
        RasterRace = all_RasterRace{pathIdx};
        NCell = size(RasterRace, 1);
        
        % Initialisation d’un vecteur pour stocker les pourcentages par SCE
        pourcentageActif = zeros(length(TRace), 1);
        
        for i = 1:length(TRace)
            % Nombre de cellules actives à l’instant TRace(i)
            nbActives = sum(RasterRace(:, TRace(i)) == 1);
            
            % Pourcentage de cellules actives
            pourcentageActif(i) = 100 * nbActives / NCell;
        end

        prop_active_cell_SCEs = mean(pourcentageActif);

        % Durée des SCEs en millisecondes
        sces_distances = all_sces_distances{m};
        distances = sces_distances(:, 2);  % Distances entre les événements SCE
        frame_duration_ms = 1000 / sampling_rate;  % Durée d'un frame en millisecondes
        durations_ms = distances * frame_duration_ms;  % Durée des SCEs en millisecondes
        avg_duration_ms = mean(durations_ms, 'omitnan');  % Durée moyenne des SCEs, en ignorant les NaNs
        
        % Stockage des résultats pour le groupe m
        all_num_sces(m) = num_sces;
        all_sce_frequency_seconds(m) = sce_frequency_seconds;
        all_avg_active_cell_SCEs(m) = avg_active_cell_SCEs;
        all_prop_active_cell_SCEs(m) = prop_active_cell_SCEs;
        all_avg_duration_ms(m) = avg_duration_ms;

    catch ME
        % Affichage d'un message d'erreur si quelque chose ne va pas
        fprintf('Erreur dans le groupe %d : %s\n', m, ME.message);
    end
end

end
