function build_rasterplot(all_DF, all_isort1, all_MAct, gcamp_output_folders, current_animal_group, current_ages_group, all_DF_all, all_isort1_all, all_blue_indices, all_MAct_blue)
    for m = 1:length(gcamp_output_folders)
        try
            % Extraction des données
            if (nargin < 7 && ~isempty(all_DF)) || (nargin > 6 && isempty(all_blue_indices))
                DF = all_DF{m};   
                isort1 = all_isort1{m};
                blue_indices = [];
                MActblue = [];

                % Création du chemin pour sauvegarder la figure
                fig_save_path = fullfile(gcamp_output_folders{m}, sprintf('%s_%s_rastermap_mtor.png', ...
                    strrep(current_animal_group, ' ', '_'), strrep(current_ages_group{m}, ' ', '_')));
                
                if exist(fig_save_path, 'file')
                    disp(['Figure already exists and was skipped: ' fig_save_path]);
                    continue;
                end

            elseif nargin > 6 && ~isempty(all_blue_indices)
                DF = all_DF_all{m};
                isort1  = all_isort1_all{m};
                blue_indices = all_blue_indices{m};
                MActblue = all_MAct_blue{m}; % Ajout de MActblue ici

                % Création du chemin pour sauvegarder la figure
                fig_save_path = fullfile(gcamp_output_folders{m}, sprintf('%s_%s_rastermap.png', ...
                    strrep(current_animal_group, ' ', '_'), strrep(current_ages_group{m}, ' ', '_')));
                
                if exist(fig_save_path, 'file')
                    disp(['Figure already exists and was skipped: ' fig_save_path]);
                    continue;
                end

             end
    
            MAct = all_MAct{m};

            if ~isempty(isort1)
                % Fix: Ensure isort1 is within bounds of DF
                isort1 = isort1(isort1 <= size(DF, 1)); % Keep only valid indices within DF
            end      

            % Proportion de cellules actives
            [NCell, ~] = size(DF);
            prop_MAct = MAct / NCell;

            if ~isempty(MActblue)   
                % Calcul du nombre de cellules bleues
                prop_MActblue = MActblue / NCell; % Proportion de cellules bleues actives
                % Calculer la corrélation pour des bins de 50 frames
                bin_size = 50;
                DF_blue = DF(blue_indices,:);    % Données pour les cellules bleues
                blue_indices_logical = ismember(1:size(DF, 1), blue_indices);
                DF_not_blue = DF(~blue_indices_logical,:);   % Données pour les autres cellules
                [bin_centers, correlation_binned] = calculate_binned_correlation(DF_not_blue, DF_blue, bin_size);
            end

            % Création de la figure
            figure;
            screen_size = get(0, 'ScreenSize');
            set(gcf, 'Position', screen_size);
            
            % Premier subplot : Raster Plot
            subplot(2, 1, 1);
            imagesc(DF(isort1, :));
            
            % Ajustements d'affichage
            [minValue, maxValue] = calculate_scaling(DF);
            clim([minValue, maxValue]);
            colorbar;
            
            axis tight;
            num_columns = size(DF, 2);
            tick_step = 1000;
            tick_positions = 0:tick_step:num_columns;
            tick_labels = arrayfun(@(x) num2str(x), tick_positions, 'UniformOutput', false);
            
            ax1 = gca;
            ax1.XAxisLocation = 'bottom';
            ax1.XTick = tick_positions;
            ax1.XTickLabel = tick_labels;
            
            % Initialisation des positions et des labels pour l'axe Y
            ytick_positions = [];
            ytick_labels = {};
            
            % Trouver les indices où isort1(i) correspond à blue_indices(j)
            if ~isempty(blue_indices)
                for i = 1:length(isort1)
                    % Trouver la correspondance dans blue_indices
                    idx = find(blue_indices == isort1(i));  % Recherche de l'index où isort1(i) correspond à blue_indices(j)
                    
                    if ~isempty(idx)  % Si une correspondance est trouvée
                        ytick_positions = [ytick_positions, i];  % Ajouter la position correspondante sur l'axe Y
                        ytick_labels = [ytick_labels, {sprintf('Neuron %d (mtor)', blue_indices(idx))}];  % Ajouter le label pour ce neurone
                    end
                end
            
                % Appliquer les positions et les labels sur l'axe Y
                ax1.YTick = ytick_positions;
                ax1.YTickLabel = ytick_labels;
            end
            
            ylabel('Neurons');
            xlabel('Number of frames');
            set(gca, 'Position', [0.1, 0.55, 0.85, 0.4]);
                        
            % Deuxième subplot : Courbe d'activité et corrélation
            subplot(2, 1, 2);
            
            % Plotting prop_MAct
            plot(prop_MAct, 'LineWidth', 2, 'DisplayName', 'Proportion of Active Cells', 'Color', 'g');
            hold on;
            
            % If MActblue exists, overlay it on the same plot with distinct style
            if ~isempty(MActblue)
                plot(prop_MActblue, 'LineWidth', 2, 'DisplayName', 'Proportion of Active Blue Cells', 'Color', 'b');
            
                % Utiliser la seconde échelle y pour la corrélation
                yyaxis right; % Passer à l'échelle y droite
                ylabel('Correlation coefficient');
                plot(bin_centers, correlation_binned, '-', 'DisplayName', sprintf('Correlation of DF gcamp vs DF blue (bin size = %d)', bin_size), 'Color', 'm');
                
                % Check for NaNs in correlation_binned and set the Y-limits accordingly
                valid_correlation = correlation_binned(~isnan(correlation_binned));
                
                if ~isempty(valid_correlation)
                    % Ajuster dynamiquement les limites de l'axe droit
                    ylim([min(valid_correlation) max(valid_correlation)]);
                else
                    % Default limits if correlation is NaN
                    ylim([-1 1]);
                end

                % Ajuster les limites des axes Y pour les deux axes
                yyaxis left;  % Retour à l'échelle y gauche
                ylim([0 1]);  % Limite pour la proportion des cellules actives
            end

            xlabel('Frame');
            ylabel('Proportion of Active Cells');
            title('Activity Over Consecutive Frames & Time-Lagged Correlation');
            grid on;
            
            % Ajouter une légende
            legend('show');
            
            % Ajuster la position du graphique pour s'assurer que les deux axes sont visibles
            set(gca, 'Position', [0.1, 0.1, 0.85, 0.35]);
            
            % Lier les axes X des deux subplots
            linkaxes([ax1, gca], 'x');
            xlim([0 num_columns]);
            
            % Sauvegarde de la figure
            saveas(gcf, fig_save_path);
            disp(['Raster plot saved in: ' fig_save_path]);
            
            % Fermeture pour libérer la mémoire
            close(gcf);

        catch ME
            fprintf('\nError: %s\n', ME.message);
        end
    end
end

% Fonction pour calculer les échelles pour le graphique basé sur les percentiles
function [min_val, max_val] = calculate_scaling(data)
    flattened_data = data(:);
    min_val = prctile(flattened_data, 5);   % 5ème percentile
    max_val = prctile(flattened_data, 99.9); % 99.9ème percentile

    % Assurer que min_val est inférieur à max_val
    if min_val >= max_val
        warning('Les limites de mise à léchelle calculées sont invalides. Ajustement aux valeurs par défaut.');
        min_val = min(flattened_data);  % Valeur minimale des données
        max_val = max(flattened_data);  % Valeur maximale des données
    end
end

function [bin_centers, correlation_binned] = calculate_binned_correlation(DF_not_blue, DF_blue, bin_size)
    
    % Calculer le nombre total de frames
    total_frames = size(DF_not_blue, 2); % Nombre de frames (colonnes)
    
    % Nombre de bins
    num_bins = floor(total_frames / bin_size);
    
    % Initialiser les variables pour stocker les résultats
    bin_centers = zeros(1, num_bins);
    correlation_binned = zeros(1, num_bins);
    
    % Boucle pour calculer la corrélation dans chaque bin
    for i = 1:num_bins
        % Définir les indices du bin
        start_idx = (i - 1) * bin_size + 1;
        end_idx = i * bin_size;
        
        % Extraire les colonnes (vecteurs d'activités) pour le bin actuel
        DF_not_blue_bin = DF_not_blue(:, start_idx:end_idx);
        DF_blue_bin = DF_blue(:, start_idx:end_idx);
        
        % Calculer la corrélation entre les neurones dans les colonnes du bin
        % Calculer la corrélation sur les colonnes (frames)
        correlation_matrix = corr(DF_not_blue_bin', DF_blue_bin');  % Corrélation sur les colonnes (frames)
        
        % Calculer la moyenne de la corrélation pour ce bin
        correlation_binned(i) = mean(correlation_matrix(:)); % Moyenne de la matrice de corrélation
        
        % Sauvegarder le centre du bin
        bin_centers(i) = (start_idx + end_idx) / 2;
    end
end
