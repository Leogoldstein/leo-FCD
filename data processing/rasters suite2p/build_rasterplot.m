function build_rasterplot(all_DF, all_isort1, all_isort1_blue, all_MAct, date_group_paths, current_animal_group, current_ages_group)
    for m = 1:length(date_group_paths)
        try
            % Extraction des données
            DF = all_DF{m};
            isort1 = all_isort1{m};
            isort1_blue = all_isort1_blue{m};
            MAct = all_MAct{m};

            disp(isort1_blue)

            if isempty(DF) || size(DF, 1) < 2 || size(DF, 2) < 2
                disp('DF est vide ou ses dimensions sont incorrectes.');
                continue;
            end

            % Création du chemin pour sauvegarder la figure
            fig_save_path = fullfile(date_group_paths{m}, sprintf('%s_%s_rastermap.png', ...
                strrep(current_animal_group, ' ', '_'), strrep(current_ages_group{m}, ' ', '_')));

            % if exist(fig_save_path, 'file')
            %     disp(['Figure already exists and was skipped: ' fig_save_path]);
            %     continue;
            % end

            % Proportion de cellules actives
            [NCell, ~] = size(DF);
            prop_MAct = MAct / NCell;

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
            tick_labels = sprintfc('%d', tick_positions);

            ax1 = gca;
            ax1.XAxisLocation = 'bottom';
            ax1.XTick = tick_positions;
            ax1.XTickLabel = tick_labels;

            ylabel('Neurons');
            xlabel('Number of frames');
            set(gca, 'Position', [0.1, 0.55, 0.85, 0.4]);

            % Deuxième subplot : Courbe d'activité
            subplot(2, 1, 2);
            plot(prop_MAct, 'LineWidth', 2);
            xlabel('Frame');
            ylabel('Proportion of Active Cells');
            title('Activity Over Consecutive Frames');
            grid on;
            set(gca, 'Position', [0.1, 0.1, 0.85, 0.35]);

            % Obtenir les limites des axes pour le subplot 1
            y_limits = ylim;
            y_range = y_limits(2) - y_limits(1);  % Plage de l'axe y

            % Tracer des flèches pour chaque élément de isort1_blue
            hold on;
            for i = 1:length(isort1_blue)
                neuron_position = isort1_blue(i);
                % Calculer la position relative sur l'axe y
                relative_position = (neuron_position - 1) / (NCell - 1);
                % Convertir en position absolue
                absolute_y_position = y_limits(1) + relative_position * y_range;
                % Ajouter une flèche à gauche de l'axe y
                quiver(-0.05, absolute_y_position, 0.05, 0, 0, 'MaxHeadSize', 5, 'Color', 'blue', 'LineWidth', 1);
            end
            hold off;

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



% Nested function to calculate scaling based on the 5th and 99.9th percentiles
function [min_val, max_val] = calculate_scaling(data)
    flattened_data = data(:);
    min_val = prctile(flattened_data, 5);   % 5th percentile
    max_val = prctile(flattened_data, 99.9); % 99.9th percentile

    % Ensure that min_val is less than max_val
    if min_val >= max_val
        warning('The calculated scaling limits are invalid. Adjusting to default values.');
        min_val = min(flattened_data);  % Fallback to min of data
        max_val = max(flattened_data);  % Fallback to max of data
    end
end


% % Filtrer les neurones avec des valeurs NaN
% valid_neurons = all(~isnan(DF), 2);
% DF = DF(valid_neurons, :);
% 
% valid_neuron_indices = find(valid_neurons);
% isort1 = isort1(ismember(isort1, valid_neuron_indices));
% [~, isort1] = ismember(isort1, valid_neuron_indices);
% 
% % Trouver les positions des cellules bleues après tri (si non vide)
% isort1_blue_positions = [];
% if ~isempty(isort1_blue)
%     isort1_blue_positions = find(ismember(isort1, isort1_blue));
%     disp(isort1_blue_positions)
% end