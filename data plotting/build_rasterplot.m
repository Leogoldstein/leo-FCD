function build_rasterplot(data, gcamp_output_folders, current_animal_group, current_ages_group, motion_energy_group)

    numFolders = numel(gcamp_output_folders);

    for m = 1:numFolders
        try
            %----------------------------------------------------------
            % 1) Déterminer si on est en mode COMBINED ou GCaMP only
            %----------------------------------------------------------
            has_combined_by_plane = isfield(data, 'DF_combined_by_plane') && ...
                                    numel(data.DF_combined_by_plane) >= m && ...
                                    ~isempty(data.DF_combined_by_plane{m});

            has_combined_global   = isfield(data, 'DF_combined') && ...
                                    numel(data.DF_combined) >= m && ...
                                    ~isempty(data.DF_combined{m});

            use_combined = has_combined_by_plane || has_combined_global;

            %----------------------------------------------------------
            % 2) Récupération DF, isort1, MAct (+ bleu si combined)
            %----------------------------------------------------------
            DF = [];
            DF_blue = [];
            isort1 = [];
            MAct = [];
            MActblue = [];
            sampling_rate = data.sampling_rate{m};

            if use_combined
                % ================= COMBINED GCaMP + BLUE =================

                % 2.a) DF combiné
                if has_combined_by_plane
                    DF = concat_planes(data, m, 'DF_combined_by_plane');
                    % isort1 global reconstruit à partir des isort par plan
                    if isfield(data, 'isort1_combined_by_plane') && ...
                       numel(data.isort1_combined_by_plane) >= m && ...
                       ~isempty(data.isort1_combined_by_plane{m})
                        isort1 = build_isort_from_planes(data, m, ...
                                    'isort1_combined_by_plane', 'DF_combined_by_plane');
                    end
                    % MAct combiné (toutes cellules)
                    if isfield(data, 'MAct_combined_by_plane') && ...
                       numel(data.MAct_combined_by_plane) >= m && ...
                       ~isempty(data.MAct_combined_by_plane{m})
                        MAct = concat_planes(data, m, 'MAct_combined_by_plane');
                    end
                end

                % Fallback sur ancienne version globale si besoin
                if isempty(DF)
                    DF = data.DF_combined{m};
                end
                if isempty(isort1) && isfield(data, 'isort1_combined') && ...
                        numel(data.isort1_combined) >= m
                    isort1 = data.isort1_combined{m};
                end
                if isempty(MAct)
                    % ancien style : MAct_not_blue ou MAct_combined
                    if isfield(data, 'MAct_gcamp_not_blue') && ...
                       numel(data.MAct_gcamp_not_blue) >= m && ...
                       ~isempty(data.MAct_gcamp_not_blue{m})
                        MAct = data.MAct_gcamp_not_blue{m};
                    elseif isfield(data, 'MAct_combined') && ...
                           numel(data.MAct_combined) >= m
                        MAct = data.MAct_combined{m};
                    end
                end

                % 2.b) Bleu : DF_blue + MActblue
                has_blue_by_plane = isfield(data, 'DF_blue_by_plane') && ...
                                    numel(data.DF_blue_by_plane) >= m && ...
                                    ~isempty(data.DF_blue_by_plane{m});

                if has_blue_by_plane
                    DF_blue = concat_planes(data, m, 'DF_blue_by_plane');
                    if isfield(data, 'MAct_blue_by_plane') && ...
                       numel(data.MAct_blue_by_plane) >= m && ...
                       ~isempty(data.MAct_blue_by_plane{m})
                        MActblue = concat_planes(data, m, 'MAct_blue_by_plane');
                    end
                elseif isfield(data, 'DF_blue') && numel(data.DF_blue) >= m
                    DF_blue = data.DF_blue{m};
                    if isfield(data, 'MAct_blue') && numel(data.MAct_blue) >= m
                        MActblue = data.MAct_blue{m};
                    end
                end

                fig_save_path = fullfile(gcamp_output_folders{m}, sprintf('%s_%s_rastermap_mtor.png', ...
                    strrep(current_animal_group, ' ', '_'), strrep(current_ages_group{m}, ' ', '_')));

            else
                % ================= GCaMP ONLY =================

                has_gcamp_by_plane = isfield(data, 'DF_gcamp_by_plane') && ...
                                     numel(data.DF_gcamp_by_plane) >= m && ...
                                     ~isempty(data.DF_gcamp_by_plane{m});

                if has_gcamp_by_plane
                    DF = concat_planes(data, m, 'DF_gcamp_by_plane');

                    if isfield(data, 'isort1_gcamp_by_plane') && ...
                       numel(data.isort1_gcamp_by_plane) >= m && ...
                       ~isempty(data.isort1_gcamp_by_plane{m})
                        isort1 = build_isort_from_planes(data, m, ...
                                    'isort1_gcamp_by_plane', 'DF_gcamp_by_plane');
                    end

                    if isfield(data, 'MAct_gcamp_by_plane') && ...
                       numel(data.MAct_gcamp_by_plane) >= m && ...
                       ~isempty(data.MAct_gcamp_by_plane{m})
                        MAct = concat_planes(data, m, 'MAct_gcamp_by_plane');
                    end
                else
                    % fallback ancien pipeline global
                    DF = data.DF_gcamp{m};
                    if isfield(data, 'isort1_gcamp') && numel(data.isort1_gcamp) >= m
                        isort1 = data.isort1_gcamp{m};
                    end
                    if isfield(data, 'MAct_gcamp') && numel(data.MAct_gcamp) >= m
                        MAct = data.MAct_gcamp{m};
                    end
                end

                fig_save_path = fullfile(gcamp_output_folders{m}, sprintf('%s_%s_rastermap.png', ...
                    strrep(current_animal_group, ' ', '_'), strrep(current_ages_group{m}, ' ', '_')));
            end

            % Si DF vide → rien à tracer
            if isempty(DF)
                fprintf('Group %d: DF is empty, skipping rasterplot.\n', m);
                continue;
            end

            % Si isort1 vide ou incohérent → identité
            [NCell, Nz] = size(DF);
            if isempty(isort1) || numel(isort1) ~= NCell
                isort1 = (1:NCell)';
            end

            % Figure déjà existante ?
            if exist(fig_save_path, 'file')
                disp(['Figure already exists and was skipped: ' fig_save_path]);
                continue;
            end

            %----------------------------------------------------------
            % 3) Préparation MAct et MActblue
            %----------------------------------------------------------
            % Adapter la longueur de MAct à Nz
            if isempty(MAct)
                MAct = zeros(1, Nz);
            else
                if numel(MAct) > Nz
                    MAct = MAct(1:Nz);
                elseif numel(MAct) < Nz
                    MAct = [MAct, zeros(1, Nz - numel(MAct))];
                end
            end
            prop_MAct = MAct / NCell;

            % Bleu
            if ~isempty(MActblue)
                [NCell_blue, Nz_blue] = size(DF_blue);
                if numel(MActblue) > Nz_blue
                    MActblue = MActblue(1:Nz_blue);
                elseif numel(MActblue) < Nz_blue
                    MActblue = [MActblue, zeros(1, Nz_blue - numel(MActblue))];
                end
                prop_MActblue = MActblue / NCell_blue;
            end

            %----------------------------------------------------------
            % 4) Config des subplots
            %----------------------------------------------------------
            has_motion_energy = nargin >= 5 && ~isempty(motion_energy_group) && ...
                                numel(motion_energy_group) >= m && ...
                                ~isempty(motion_energy_group{m});

            subplot_count = 2 + ~isempty(MActblue) + has_motion_energy;
            subplot_idx = 2;

            % Création figure
            figure;
            screen_size = get(0, 'ScreenSize');
            set(gcf, 'Position', screen_size);

            t_idx = 1:Nz;

            % Subplot 1 : Raster plot
            subplot(subplot_count, 1, 1);
            imagesc(DF(isort1, :));
            [minValue, maxValue] = calculate_scaling(DF);
            clim([minValue, maxValue]);
            axis tight;

            ax1 = gca;
            ax1.XTick = round(linspace(1, Nz, 6));
            ax1.XTickLabel = arrayfun(@(x) sprintf('%d', x), ax1.XTick, 'UniformOutput', false);
            ylabel('Neurons');
            xlabel('Time (frame index)');
            title('Raster Plot');
            xlim([1 Nz]);

            % Subplot 2 : proportion active cells (all)
            subplot(subplot_count, 1, 2);
            plot(t_idx, prop_MAct, 'LineWidth', 2, 'Color', 'g');
            ylabel('Prop. Active Cells');
            title('Proportion of Active Cells (All)');
            grid on;
            xlim([1, Nz]);

            % Subplot cellules bleues
            subplot_idx = 3;
            if ~isempty(MActblue)
                subplot(subplot_count, 1, subplot_idx);
                plot(t_idx, prop_MActblue, 'LineWidth', 2, 'Color', 'b');
                ylim([0 1]);
                xlabel('Time (frame index)');
                ylabel('Prop. Blue Active Cells');
                title('Proportion of Active Blue Cells');
                grid on;
                xlim([1, Nz]);
                subplot_idx = subplot_idx + 1;
            end

            % Subplot motion energy
            if has_motion_energy
                subplot(subplot_count, 1, subplot_idx);
                hold on;

                energy = motion_energy_group{m};
                if isempty(energy)
                    % rien à tracer
                else
                    % X étiré de 1 à Nz
                    x_stretched = linspace(1, Nz, numel(energy));
                    plot(x_stretched, energy, 'DisplayName', sprintf('Session %d', m));
                    xlabel('Time (frame index)');
                    ylabel('Normalized Energy');
                    xlim([1 Nz]);
                    title('Motion Energy (Downsampled)');
                    legend show;
                    grid on;
                end

                hold off;
            end

            % Lier les axes X
            ax_all = findall(gcf, 'Type', 'axes');
            linkaxes(ax_all, 'x');

            % Sauvegarde
            saveas(gcf, fig_save_path);
            disp(['Raster plot saved in: ' fig_save_path]);
            close(gcf)

        catch ME
            fprintf('\nError for group %d: %s\n', m, ME.message);
        end
    end
end

%---------------------------------------------
% Fonctions utilitaires
%---------------------------------------------
function [min_val, max_val] = calculate_scaling(data)
    flattened_data = data(:);
    min_val = prctile(flattened_data, 5);
    max_val = prctile(flattened_data, 99.9);
    if min_val >= max_val
        warning('Invalid color scale limits, using raw min/max.');
        min_val = min(flattened_data);
        max_val = max(flattened_data);
    end
end

function isort_global = build_isort_from_planes(data, m, isort_field, DF_field)
% Reconstruit un isort1 global à partir des isort par plan
% en tenant compte du nombre de cellules par plan (DF_field).

    isort_global = [];

    if ~isfield(data, isort_field) || ~isfield(data, DF_field) || ...
       numel(data.(isort_field)) < m || numel(data.(DF_field)) < m || ...
       isempty(data.(DF_field){m})
        return;
    end

    isort_cell = data.(isort_field){m};
    DF_cell    = data.(DF_field){m};

    if isempty(isort_cell) || isempty(DF_cell)
        return;
    end

    offset = 0;
    for p = 1:numel(DF_cell)
        DFp = DF_cell{p};
        if isempty(DFp)
            continue;
        end

        n_p = size(DFp, 1);

        if p <= numel(isort_cell) && ~isempty(isort_cell{p})
            local_isort = isort_cell{p};
        else
            local_isort = (1:n_p)';
        end

        % Sanity check
        local_isort = local_isort(:);
        local_isort(local_isort < 1 | local_isort > n_p) = [];  % clamp

        isort_global = [isort_global; local_isort + offset]; %#ok<AGROW>
        offset = offset + n_p;
    end
end
