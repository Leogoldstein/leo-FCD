function plot_pairwise_corr(current_ages_group, max_corr_gcamp_gcamp, current_ani_path_group, animal_name)

    try
        corrTypeLabel = 'gcamp-gcamp';

        % ---- output ----
        file_name = sprintf('Corr_%s_%s.png', animal_name, corrTypeLabel);
        save_path = fullfile(current_ani_path_group, file_name);
        if exist(save_path, 'file')
            fprintf('La figure "%s" existe déjà. Passage au suivant.\n', save_path);
            return;
        end

        % ---- usable sessions ----
        nUse = min(numel(current_ages_group), numel(max_corr_gcamp_gcamp));
        if nUse == 0
            warning('Aucune session utilisable pour %s.', animal_name);
            return;
        end

        % ---- detect nPlanes ----
        nPlanes = 0;
        for s = 1:nUse
            if isempty(max_corr_gcamp_gcamp{s}), continue; end
            if iscell(max_corr_gcamp_gcamp{s})
                nPlanes = max(nPlanes, numel(max_corr_gcamp_gcamp{s}));
            else
                nPlanes = max(nPlanes, 1);
            end
        end
        if nPlanes == 0
            warning('Aucun plan détecté pour %s.', animal_name);
            return;
        end

        % ---- first pass: gather per plane:
        % - distribution vectors + age labels
        % - mean matrices per age (heatmaps)
        planeDistData = cell(nPlanes,1);     % vector
        planeDistAge  = cell(nPlanes,1);     % cellstr labels (same length as vector)
        planeAgeKeys  = cell(nPlanes,1);     % ordered age labels present for that plane
        planeMeanMats = cell(nPlanes,1);     % cell array {iAge} = mean matrix

        agesWanted = arrayfun(@(x) sprintf('P%d',x), 7:15, 'UniformOutput', false);

        nAgesMax = 0;
        for p = 1:nPlanes
            distVec = [];
            distLab = {};
            ageMatrices = containers.Map('KeyType','char','ValueType','any');

            for sessionIdx = 1:nUse
                ageLabel = normalize_age_label(current_ages_group{sessionIdx});

                v = fetch_plane_corr(max_corr_gcamp_gcamp, sessionIdx, p);
                if isempty(v), continue; end

                % dist
                v_vec = corr_to_unique_pairs(v);
                if ~isempty(v_vec)
                    distVec = [distVec; v_vec(:)];
                    distLab = [distLab; repmat({ageLabel}, numel(v_vec), 1)];
                end

                % heatmap matrices
                if ismatrix(v) && size(v,1)==size(v,2) && size(v,1)>1
                    if ~isKey(ageMatrices, ageLabel)
                        ageMatrices(ageLabel) = {v};
                    else
                        tmp = ageMatrices(ageLabel);
                        tmp{end+1} = v;
                        ageMatrices(ageLabel) = tmp;
                    end
                end
            end

            planeDistData{p} = distVec;
            planeDistAge{p}  = distLab;

            if isempty(keys(ageMatrices))
                planeAgeKeys{p}  = {};
                planeMeanMats{p} = {};
                continue;
            end

            % order ages: P7..P15 first, then others
            keysIn = keys(ageMatrices);
            orderedKeys = {};
            for i = 1:numel(agesWanted)
                if any(strcmp(keysIn, agesWanted{i}))
                    orderedKeys{end+1} = agesWanted{i}; %#ok<AGROW>
                end
            end
            for i = 1:numel(keysIn)
                if ~any(strcmp(orderedKeys, keysIn{i}))
                    orderedKeys{end+1} = keysIn{i}; %#ok<AGROW>
                end
            end

            meanMats = cell(1, numel(orderedKeys));
            for i = 1:numel(orderedKeys)
                mats = ageMatrices(orderedKeys{i});
                meanMat = zeros(size(mats{1}));
                for k = 1:numel(mats)
                    meanMat = meanMat + mats{k};
                end
                meanMats{i} = meanMat / numel(mats);
            end

            planeAgeKeys{p}  = orderedKeys;
            planeMeanMats{p} = meanMats;

            nAgesMax = max(nAgesMax, numel(orderedKeys));
        end

        if nAgesMax == 0
            % no heatmaps anywhere -> still plot distributions
            nAgesMax = 0;
        end

        % ---- figure layout: rows = planes, cols = 1 + max ages ----
        nCols = 1 + nAgesMax;

        figW = max(1200, 420*nCols);
        figH = max(500, 320*nPlanes);

        fig = figure('Name', sprintf('%s - %s', animal_name, corrTypeLabel), ...
                     'Position', [80, 80, figW, figH]);

        tl = tiledlayout(nPlanes, nCols, 'TileSpacing', 'compact', 'Padding', 'compact');
        title(tl, sprintf('%s - %s (distribution + mean corr heatmaps by age)', animal_name, corrTypeLabel));

        % Optional: keep same color scaling for all heatmaps in the whole figure
        % Compute global min/max across all mean mats
        globalMin = inf; globalMax = -inf;
        for p = 1:nPlanes
            mats = planeMeanMats{p};
            for i = 1:numel(mats)
                globalMin = min(globalMin, min(mats{i}(:)));
                globalMax = max(globalMax, max(mats{i}(:)));
            end
        end
        if ~isfinite(globalMin) || ~isfinite(globalMax)
            globalMin = 0; globalMax = 1;
        end

        % ---- render each plane row ----
        for p = 1:nPlanes
            % (1) Distribution tile
            nexttile(tl, (p-1)*nCols + 1);

            distVec = planeDistData{p};
            distLab = planeDistAge{p};

            if isempty(distVec)
                text(0.5,0.5,sprintf('Plan %d : aucune donnée',p),'HorizontalAlignment','center');
                axis off;
            else
                uniqueAges = unique(distLab,'stable');
                if numel(uniqueAges) == 1
                    histogram(distVec);
                    xlabel('Pairwise corr'); ylabel('Count');
                    title(sprintf('Plan %d – %s', p, uniqueAges{1}));
                else
                    ordered_age = categorical(distLab, uniqueAges, 'Ordinal', true);
                    [~,idx] = sort(ordered_age);
                    violinplot(distVec(idx), ordered_age(idx));
                    ylabel('Pairwise corr');
                    title(sprintf('Plan %d', p));
                    xticklabels(uniqueAges);
                end
            end

            % (2) Heatmaps tiles (one per age)
            ageKeys = planeAgeKeys{p};
            meanMats = planeMeanMats{p};

            for a = 1:nAgesMax
                nexttile(tl, (p-1)*nCols + 1 + a);

                if a > numel(meanMats)
                    axis off; % empty tile
                    continue;
                end

                imagesc(meanMats{a});
                axis image;
                colormap(parula);
                colorbar;
                caxis([globalMin globalMax]); % same scale across all tiles
                title(sprintf('%s', ageKeys{a}));
                xlabel('Neuron'); ylabel('Neuron');
            end
        end

        saveas(fig, save_path, 'png');
        close(fig);

    catch ME
        warning('Erreur rencontrée pour %s : %s', animal_name, ME.message);
    end
end

% ========================= helpers =========================

function ageLabel = normalize_age_label(ageStr)
    if isstring(ageStr), ageStr = char(ageStr); end
    ageStr = strtrim(ageStr);
    tok = regexp(ageStr, '\d+', 'match', 'once');
    if isempty(tok)
        ageLabel = ageStr;
    else
        ageLabel = ['P' tok];
    end
end

function v = fetch_plane_corr(max_corr_gcamp_gcamp, sessionIdx, p)
    v = [];
    if sessionIdx > numel(max_corr_gcamp_gcamp), return; end
    if isempty(max_corr_gcamp_gcamp{sessionIdx}), return; end

    if iscell(max_corr_gcamp_gcamp{sessionIdx})
        if p > numel(max_corr_gcamp_gcamp{sessionIdx}), return; end
        v = max_corr_gcamp_gcamp{sessionIdx}{p};
    else
        if p ~= 1, return; end
        v = max_corr_gcamp_gcamp{sessionIdx};
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
