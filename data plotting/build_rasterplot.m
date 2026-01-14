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
            % 2) Récupération DF, isort1 (+ bleu si combined)
            %----------------------------------------------------------
            DF = [];
            DF_blue = [];
            isort1 = [];
            sampling_rate = data.sampling_rate{m};

            if use_combined
                % ================= COMBINED GCaMP + BLUE =================
                if has_combined_by_plane
                    DF = concat_planes(data, m, 'DF_combined_by_plane');

                    if isfield(data, 'isort1_combined_by_plane') && ...
                       numel(data.isort1_combined_by_plane) >= m && ...
                       ~isempty(data.isort1_combined_by_plane{m})
                        isort1 = build_isort_from_planes(data, m, ...
                                    'isort1_combined_by_plane', 'DF_combined_by_plane');
                    end
                end

                if isempty(DF)
                    DF = data.DF_combined{m};
                end
                if isempty(isort1) && isfield(data, 'isort1_combined') && ...
                        numel(data.isort1_combined) >= m
                    isort1 = data.isort1_combined{m};
                end

                % Bleu
                has_blue_by_plane = isfield(data, 'DF_blue_by_plane') && ...
                                    numel(data.DF_blue_by_plane) >= m && ...
                                    ~isempty(data.DF_blue_by_plane{m});
                if has_blue_by_plane
                    DF_blue = concat_planes(data, m, 'DF_blue_by_plane');
                elseif isfield(data, 'DF_blue') && numel(data.DF_blue) >= m
                    DF_blue = data.DF_blue{m};
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
                else
                    DF = data.DF_gcamp{m};
                    if isfield(data, 'isort1_gcamp') && numel(data.isort1_gcamp) >= m
                        isort1 = data.isort1_gcamp{m};
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

            % isort1 : identité si vide ou incohérent
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
            % 3) MAct et MActblue : SOMME par plan (pas concat)
            %----------------------------------------------------------
            MAct = [];
            MActblue = [];

            if use_combined
                if isfield(data, 'MAct_combined_by_plane') && ...
                   numel(data.MAct_combined_by_plane) >= m && ...
                   ~isempty(data.MAct_combined_by_plane{m})
                    MAct = merge_MAct_planes(data, m, 'MAct_combined_by_plane', Nz);
                elseif isfield(data, 'MAct_combined') && numel(data.MAct_combined) >= m
                    MAct = resize_MAct(data.MAct_combined{m}, Nz);
                elseif isfield(data, 'MAct_gcamp_not_blue') && numel(data.MAct_gcamp_not_blue) >= m
                    MAct = resize_MAct(data.MAct_gcamp_not_blue{m}, Nz);
                end

                % Bleu
                if ~isempty(DF_blue)
                    Nz_blue = size(DF_blue,2);
                    if isfield(data, 'MAct_blue_by_plane') && ...
                       numel(data.MAct_blue_by_plane) >= m && ...
                       ~isempty(data.MAct_blue_by_plane{m})
                        MActblue = merge_MAct_planes(data, m, 'MAct_blue_by_plane', Nz_blue);
                    elseif isfield(data, 'MAct_blue') && numel(data.MAct_blue) >= m
                        MActblue = resize_MAct(data.MAct_blue{m}, Nz_blue);
                    end
                end
            else
                if isfield(data, 'MAct_gcamp_by_plane') && ...
                   numel(data.MAct_gcamp_by_plane) >= m && ...
                   ~isempty(data.MAct_gcamp_by_plane{m})
                    MAct = merge_MAct_planes(data, m, 'MAct_gcamp_by_plane', Nz);
                elseif isfield(data, 'MAct_gcamp') && numel(data.MAct_gcamp) >= m
                    MAct = resize_MAct(data.MAct_gcamp{m}, Nz);
                end
            end

            if isempty(MAct)
                MAct = zeros(1, Nz);
            end
            prop_MAct = MAct / NCell;

            if ~isempty(MActblue) && ~isempty(DF_blue)
                NCell_blue = size(DF_blue,1);
                prop_MActblue = MActblue / NCell_blue;
            else
                prop_MActblue = [];
            end

            %----------------------------------------------------------
            % 4) Config des subplots
            %----------------------------------------------------------
            has_motion_energy = nargin >= 5 && ~isempty(motion_energy_group) && ...
                                numel(motion_energy_group) >= m && ...
                                ~isempty(motion_energy_group{m});

            subplot_count = 2 + ~isempty(prop_MActblue) + has_motion_energy;

            % Création figure
            fig = figure;
            set(fig, 'Position', get(0, 'ScreenSize'));

            % Temps en secondes
            total_time = Nz / sampling_rate;
            t_sec = (0:Nz-1) / sampling_rate;

            % Subplot 1 : Raster plot (en secondes)
            subplot(subplot_count, 1, 1);
            imagesc(t_sec, 1:NCell, DF(isort1, :));
            [minValue, maxValue] = calculate_scaling(DF);
            clim([minValue, maxValue]);
            axis tight;
            ylabel('Neurons');
            xlabel('Time (s)');
            title('Raster Plot');
            xlim([0 total_time]);

            % Subplot 2 : proportion active cells (all)
            subplot(subplot_count, 1, 2);
            plot(t_sec, prop_MAct, 'LineWidth', 2, 'Color', 'g');
            ylabel('Prop. Active Cells');
            title('Proportion of Active Cells (All)');
            grid on;
            xlim([0 total_time]);

            % Subplot cellules bleues
            subplot_idx = 3;
            if ~isempty(prop_MActblue)
                subplot(subplot_count, 1, subplot_idx);
                plot(t_sec, prop_MActblue, 'LineWidth', 2, 'Color', 'b');
                ylim([0 1]);
                xlabel('Time (s)');
                ylabel('Prop. Blue Active Cells');
                title('Proportion of Active Blue Cells');
                grid on;
                xlim([0 total_time]);
                subplot_idx = subplot_idx + 1;
            end

            % Subplot motion energy
            if has_motion_energy
                subplot(subplot_count, 1, subplot_idx);
                hold on;

                energy = motion_energy_group{m};
                if ~isempty(energy)
                    x_stretched = linspace(0, total_time, numel(energy));
                    plot(x_stretched, energy, 'DisplayName', sprintf('Session %d', m));
                    xlabel('Time (s)');
                    ylabel('Normalized Energy');
                    xlim([0 total_time]);
                    title('Motion Energy (Downsampled)');
                    legend show;
                    grid on;
                end

                hold off;
            end

            % Lier les axes X
            linkaxes(findall(fig, 'Type', 'axes'), 'x');

            % Sauvegarde
            saveas(fig, fig_save_path);
            disp(['Raster plot saved in: ' fig_save_path]);
            close(fig);

        catch ME
            fprintf('\nError for group %d: %s\n', m, ME.message);
            if exist('fig','var') && ishghandle(fig)
                close(fig);
            end
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

function MAct_out = resize_MAct(MAct_in, Nz)
    % Ajuste un vecteur MAct à Nz (crop/pad en fin)
    if isempty(MAct_in)
        MAct_out = zeros(1, Nz);
        return;
    end
    MAct_in = MAct_in(:)'; % row
    if numel(MAct_in) > Nz
        MAct_out = MAct_in(1:Nz);
    elseif numel(MAct_in) < Nz
        MAct_out = [MAct_in, zeros(1, Nz - numel(MAct_in))];
    else
        MAct_out = MAct_in;
    end
end

function MAct_sum = merge_MAct_planes(data, m, fieldName, Nz)
    % SOMME des MAct_by_plane{m}{p} (même axe temps, pas concat)
    MAct_sum = zeros(1, Nz);

    if ~isfield(data, fieldName) || numel(data.(fieldName)) < m || isempty(data.(fieldName){m})
        return;
    end

    MAct_cell = data.(fieldName){m};
    for p = 1:numel(MAct_cell)
        M_p = MAct_cell{p};
        if isempty(M_p)
            continue;
        end
        M_p = resize_MAct(M_p, Nz);
        MAct_sum = MAct_sum + M_p;
    end
end

function out = concat_planes(data, m, fieldName)
    planes = data.(fieldName){m};
    if isempty(planes)
        out = [];
        return;
    end

    sample = [];
    for p = 1:numel(planes)
        if ~isempty(planes{p})
            sample = planes{p};
            break;
        end
    end
    if isempty(sample)
        out = [];
        return;
    end

    if isnumeric(sample)
        out = [];
        for p = 1:numel(planes)
            if ~isempty(planes{p})
                out = [out; planes{p}]; %#ok<AGROW>
            end
        end
    elseif iscell(sample)
        out = {};
        for p = 1:numel(planes)
            if ~isempty(planes{p})
                out = [out; planes{p}(:)]; %#ok<AGROW>
            end
        end
    else
        error('concat_planes: type non supporté (%s) pour "%s".', class(sample), fieldName);
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
        local_isort(local_isort < 1 | local_isort > n_p) = [];

        isort_global = [isort_global; local_isort + offset]; %#ok<AGROW>
        offset = offset + n_p;
    end
end
