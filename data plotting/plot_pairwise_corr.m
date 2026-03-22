function plot_pairwise_corr(current_ages_group, max_corr_gcamp_gcamp_by_plane, gcamp_output_folders, animal_name)

    corrTypeLabel = 'gcamp-gcamp';

    numFolders = numel(gcamp_output_folders);

    for m = 1:numFolders
        fig = [];
        try
            if m > numel(max_corr_gcamp_gcamp_by_plane) || isempty(max_corr_gcamp_gcamp_by_plane{m})
                warning("m=%d: max_corr vide. Skip.", m);
                continue;
            end

            % ---- âge de cette session ----
            if m <= numel(current_ages_group) && ~isempty(current_ages_group{m})
                ageLabel = normalize_age_label(current_ages_group{m});
            else
                ageLabel = sprintf('sess%d', m);
            end

            corr_planes = max_corr_gcamp_gcamp_by_plane{m};
            if ~iscell(corr_planes)
                corr_planes = {corr_planes};
            end
            nPlanes = numel(corr_planes);
            
            % ---- vérifier données non vides ----
            hasData = false;
            for p = 1:nPlanes
                V = corr_planes{p};
                if ~isempty(V)
                    if ismatrix(V) && size(V,1)==size(V,2) && size(V,1)>1
                        hasData = true; break;
                    elseif ~isempty(V(:))
                        hasData = true; break;
                    end
                end
            end
            
            if ~hasData
                fprintf('m=%d: toutes les données sont vides. Skip.\n', m);
                continue;
            end

            % ---- output ----
            file_name = sprintf('Corr_%s_%s_%s_m%d.png', ...
                char(string(animal_name)), corrTypeLabel, ageLabel, m);
            save_path = fullfile(gcamp_output_folders{m}, file_name);
            save_path = char(string(save_path));

            if exist(save_path, 'file')
                fprintf('La figure "%s" existe déjà. Passage au suivant.\n', save_path);
                continue;
            end

            % ---- layout : 2 colonnes (dist + heatmap) x nPlanes lignes ----
            nRows = nPlanes;
            nCols = 2;

            figW = 1400;
            figH = max(500, 320*nRows);

            fig = figure('Name', sprintf('%s - %s - %s - m=%d', char(string(animal_name)), corrTypeLabel, ageLabel, m), ...
                         'Position', [80, 80, figW, figH]);

            tl = tiledlayout(nRows, nCols, 'TileSpacing', 'compact', 'Padding', 'compact');
            title(tl, sprintf('%s - %s | %s | session m=%d (dist + heatmap par plan)', ...
                char(string(animal_name)), corrTypeLabel, ageLabel, m));

            % ---- global clim pour heatmaps (sur tous les plans de la session) ----
            globalMin = inf; globalMax = -inf;
            for p = 1:nPlanes
                V = corr_planes{p};
                if isempty(V), continue; end
                if ismatrix(V) && size(V,1)==size(V,2) && size(V,1)>1
                    globalMin = min(globalMin, min(V(:)));
                    globalMax = max(globalMax, max(V(:)));
                end
            end
            if ~isfinite(globalMin) || ~isfinite(globalMax) || globalMax <= globalMin
                globalMin = -1; globalMax = 1;
            end

            % ---- plot par plan ----
            for p = 1:nPlanes
                V = corr_planes{p};

                % (1) distribution
                nexttile(tl, (p-1)*nCols + 1);
                if isempty(V)
                    text(0.5,0.5,sprintf('Plan %d : aucune donnée', p), 'HorizontalAlignment','center');
                    axis off;
                else
                    v_vec = corr_to_unique_pairs(V);
                    if isempty(v_vec)
                        text(0.5,0.5,sprintf('Plan %d : vide', p), 'HorizontalAlignment','center');
                        axis off;
                    else
                        histogram(v_vec, 50);
                        xlabel('Pairwise corr'); ylabel('Count');
                        title(sprintf('Plan %d – %s', p, ageLabel));
                        grid on;
                    end
                end

                % (2) heatmap
                nexttile(tl, (p-1)*nCols + 2);
                if isempty(V) || ~(ismatrix(V) && size(V,1)==size(V,2) && size(V,1)>1)
                    text(0.5,0.5,sprintf('Plan %d : pas de matrice NxN', p), 'HorizontalAlignment','center');
                    axis off;
                else
                    imagesc(V);
                    axis image;
                    colormap(parula);
                    colorbar;
                    caxis([globalMin globalMax]);
                    title(sprintf('Heatmap – Plan %d', p));
                    xlabel('Neuron'); ylabel('Neuron');
                end
            end

            saveas(fig, save_path, 'png');
            close(fig);
            fprintf('Saved: %s\n', save_path);

        catch ME
            warning("Erreur rencontrée pour " + string(animal_name) + " (m=" + string(m) + ") : " + string(ME.message));
            if ~isempty(fig) && ishghandle(fig), close(fig); end
        end
    end
end

% ========================= helpers =========================

function ageLabel = normalize_age_label(ageStr)
    ageStr = char(string(ageStr));
    ageStr = strtrim(ageStr);
    tok = regexp(ageStr, '\d+', 'match', 'once');
    if isempty(tok)
        ageLabel = ageStr;
    else
        ageLabel = ['P' tok];
    end
end

function v_vec = corr_to_unique_pairs(v)
    if isempty(v)
        v_vec = [];
        return;
    end
    if ismatrix(v) && size(v,1)==size(v,2) && size(v,1)>1
        v_vec = v(triu(true(size(v)), 1)); % upper triangle only
    else
        v_vec = v(:);
    end
end