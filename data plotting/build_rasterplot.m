function build_rasterplot(data, gcamp_output_folders, current_animal_group, current_ages_group, sampling_rate_group, motion_energy_smooth_group, speed_active_group)

    numFolders = numel(gcamp_output_folders);

    for m = 1:numFolders
        fig = [];
        try
            %----------------------------------------------------------
            % 0) Charger speed_active (0/1 frame caméra) depuis results_movie.mat
            %----------------------------------------------------------
            speed_active = speed_active_group{m};

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
            sampling_rate = sampling_rate_group{m};

            if use_combined
                % ================= COMBINED =================
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

            if isempty(DF)
                fprintf('Group %d: DF is empty, skipping rasterplot.\n', m);
                continue;
            end

            [NCell, Nz] = size(DF);

            if isempty(isort1) || numel(isort1) ~= NCell
                isort1 = (1:NCell)';
            else
                isort1 = isort1(:);
                bad = isort1 < 1 | isort1 > NCell | isnan(isort1);
                if any(bad), isort1(bad) = []; end
                if numel(isort1) ~= NCell || numel(unique(isort1)) ~= numel(isort1)
                    isort1 = (1:NCell)';
                end
            end

            if exist(fig_save_path, 'file')
                disp(['Figure already exists and was skipped: ' fig_save_path]);
                continue;
            end

            %----------------------------------------------------------
            % 3) MAct (+ blue si applicable)
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

            if isempty(MAct), MAct = zeros(1, Nz); end
            prop_MAct = MAct / NCell;

            if ~isempty(MActblue) && ~isempty(DF_blue)
                NCell_blue = size(DF_blue,1);
                prop_MActblue = MActblue / NCell_blue;
            else
                prop_MActblue = [];
            end

            %----------------------------------------------------------
            % 4) Config subplots + time axes
            %----------------------------------------------------------
            has_motion_energy = (nargin >= 6) && ~isempty(motion_energy_smooth_group) && ...
                                numel(motion_energy_smooth_group) >= m && ...
                                ~isempty(motion_energy_smooth_group{m});

            subplot_count = 2 + ~isempty(prop_MActblue) + has_motion_energy;

            fig = figure;
            set(fig, 'Position', get(0, 'ScreenSize'));

            total_time = Nz / sampling_rate;
            t_sec = (0:Nz-1) / sampling_rate;

            % --------- Préparer segments d’activité en secondes ----------
            % speed_active est par frame caméra (longueur L), on le mappe sur [0,total_time]
            activity_segs_sec = [];
            if ~isempty(speed_active)
                L = numel(speed_active);
                t_speed = linspace(0, total_time, L);
                activity_segs_sec = mask_to_segments_time(t_speed, speed_active > 0);
            end

            %----------------------------------------------------------
            % Subplot 1 : Raster plot CONTINU (non binarisé)
            %----------------------------------------------------------
            ax1 = subplot(subplot_count, 1, 1);   % <<< OBLIGATOIRE
            A = DF(isort1, :);
            
            % --- z-score robuste continu ---
            A_z = nan(size(A));
            for i = 1:size(A,1)
                x = A(i,:);
                mu = median(x,'omitnan');
                sig = 1.4826 * mad(x,1);   % sigma robuste
                if isfinite(sig) && sig > eps
                    A_z(i,:) = (x - mu) / sig;
                else
                    A_z(i,:) = x - mu;
                end
            end
            
            imagesc(ax1, t_sec, 1:NCell, A_z);
            axis(ax1, 'tight');
            set(ax1, 'YDir','normal');
            xlabel(ax1, 'Time (s)');
            ylabel(ax1, 'Neurons');
            
            colormap(ax1, parula);
            
            % saturation robuste
            v = A_z(isfinite(A_z));
            if ~isempty(v)
                lo = prctile(v, 2);
                hi = prctile(v, 98);
                if isfinite(lo) && isfinite(hi) && hi > lo
                    clim(ax1, [lo hi]);   % sinon caxis([lo hi])
                end
            end
            colorbar(ax1);
            title(ax1, 'Raster plot (activité continue, z-score robuste)');
            xlim(ax1, [0 total_time]);
            
            % bandes d’activité
            plot_activity_bands(ax1, activity_segs_sec);

            %----------------------------------------------------------
            % Subplot 2 : proportion active cells (all) + activité
            %----------------------------------------------------------
            ax2 = subplot(subplot_count, 1, 2);
            plot(t_sec, prop_MAct, 'LineWidth', 2);
            ylabel('Prop. Active Cells');
            title('Proportion of Active Cells (All)');
            grid on;
            xlim([0 total_time]);

            plot_activity_bands(ax2, activity_segs_sec);

            %----------------------------------------------------------
            % Subplot blue (si applicable) + activité
            %----------------------------------------------------------
            subplot_idx = 3;
            if ~isempty(prop_MActblue)
                axb = subplot(subplot_count, 1, subplot_idx);
                plot(t_sec, prop_MActblue, 'LineWidth', 2);
                ylim([0 1]);
                xlabel('Time (s)');
                ylabel('Prop. Blue Active Cells');
                title('Proportion of Active Blue Cells');
                grid on;
                xlim([0 total_time]);

                plot_activity_bands(axb, activity_segs_sec);

                subplot_idx = subplot_idx + 1;
            end

            %----------------------------------------------------------
            % Subplot motion energy (si applicable) + activité
            %----------------------------------------------------------
            if has_motion_energy
                axm = subplot(subplot_count, 1, subplot_idx);
                hold on;

                energy = motion_energy_smooth_group{m};
                if ~isempty(energy)
                    x_stretched = linspace(0, total_time, numel(energy));
                    plot(x_stretched, energy, 'DisplayName', sprintf('Session %d', m));
                    xlabel('Time (s)');
                    ylabel('Motion energy');
                    xlim([0 total_time]);
                    title('Motion Energy');
                    grid on;
                end
                hold off;

                plot_activity_bands(axm, activity_segs_sec);
            end

            linkaxes(findall(fig, 'Type', 'axes'), 'x');

            saveas(fig, fig_save_path);
            disp(['Raster plot saved in: ' fig_save_path]);
            close(fig);

        catch ME
            fprintf('\nError for group %d: %s\n', m, ME.message);
            if ~isempty(fig) && ishghandle(fig)
                close(fig);
            end
        end
    end
end


%---------------------------------------------
% Fonctions utilitaires
%---------------------------------------------

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


function segs_sec = mask_to_segments_time(t, mask)
% t : 1xL temps en secondes
% mask : 1xL logique
% segs_sec : Nx2 [t_start t_end]

    mask = mask(:)'; 
    t = t(:)';

    if isempty(mask)
        segs_sec = [];
        return;
    end

    d = diff([false, mask, false]);
    starts = find(d == 1);
    ends   = find(d == -1) - 1;

    segs_sec = [t(starts(:))', t(ends(:))'];
end

function plot_activity_bands(ax, segs_sec)
% Ajoute des bandes verticales (activité) derrière les courbes sur l’axe ax

    if isempty(segs_sec)
        return;
    end

    axes(ax); %#ok<LAXES>
    yl = ylim(ax);
    hold(ax, 'on');

    for k = 1:size(segs_sec,1)
        x1 = segs_sec(k,1);
        x2 = segs_sec(k,2);
        patch(ax, [x1 x2 x2 x1], [yl(1) yl(1) yl(2) yl(2)], ...
              [1 0.8 0.8], 'EdgeColor','none', 'FaceAlpha',0.25);
    end

    % remet les limites (patch peut les changer)
    ylim(ax, yl);
    hold(ax, 'off');
end