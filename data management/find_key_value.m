function [recording_time, sampling_rate, sampling_rate_per_plane, interplane_delay_s, optical_zoom, position, time_minutes, pixel_size, n_plans] = find_key_value(path)
    % Fonction pour extraire les métadonnées d'un fichier XML Prairie View :
    %   - Heure d'enregistrement
    %   - Framerate global Prairie (Hz), sans tenir compte des déplacements
    %   - Framerate estimé par plan (Hz)
    %   - Délai inter-plan estimé (s)
    %   - Optical zoom
    %   - Position Z (µm) :
    %       * TSeries simple : scalaire
    %       * TSeries ZSeries : vecteur (1 valeur par plan)
    %   - Durée totale (en minutes)
    %   - Taille d’un pixel (µm/pixel)
    %   - Nombre de plans Z (n_plans)
    %
    % Entrée :
    %   path : chemin complet vers le fichier XML Prairie View (.xml)

    % -----------------------------
    % Valeurs par défaut
    % -----------------------------
    recording_time          = '';
    sampling_rate           = NaN;   % framerate global Prairie
    sampling_rate_per_plane = NaN;   % framerate réel par plan
    interplane_delay_s      = NaN;   % délai estimé entre deux plans
    optical_zoom            = NaN;
    position                = NaN;   % scalaire ou vecteur
    time_minutes            = NaN;
    pixel_size              = NaN;
    n_plans                 = 1;

    pixel_size_x = NaN;
    pixel_size_y = NaN;

    % Convertit "4,17" -> 4.17
    str2num_local = @(s) str2double(strrep(char(s), ',', '.'));

    try
        %% === Lecture du fichier XML ===
        xmlDoc = xmlread(path);

        %% === Heure d'enregistrement ===
        rootNode = xmlDoc.getDocumentElement();  % normalement PVScan
        full_date = '';

        if ~isempty(rootNode) && rootNode.hasAttribute('date')
            full_date = char(rootNode.getAttribute('date'));
        else
            envNode = xmlDoc.getElementsByTagName('Environment').item(0);
            if ~isempty(envNode) && envNode.hasAttribute('date')
                full_date = char(envNode.getAttribute('date'));
            end
        end

        if ~isempty(full_date)
            split_date = strsplit(full_date);
            if numel(split_date) > 1
                recording_time = split_date{2};
                if numel(split_date) > 2
                    recording_time = [recording_time ' ' split_date{3}];
                end
            end
        end

        %% === Extraction des PVStateValue globaux ===
        pvNodes = xmlDoc.getElementsByTagName('PVStateValue');

        for i = 0:pvNodes.getLength-1
            currentNode = pvNodes.item(i);
            key = char(currentNode.getAttribute('key'));

            % --- Sampling rate global Prairie ---
            if strcmp(key, 'framerate')
                sampling_rate = str2num_local(currentNode.getAttribute('value'));

            elseif strcmp(key, 'framePeriod') && isnan(sampling_rate)
                fp = str2num_local(currentNode.getAttribute('value')); % secondes
                if ~isnan(fp) && fp > 0
                    sampling_rate = 1 / fp;
                end
            end

            % --- Optical zoom ---
            if strcmp(key, 'opticalZoom')
                optical_zoom = str2num_local(currentNode.getAttribute('value'));
            end

            % --- Position Z globale (fallback pour TSeries simple) ---
            if strcmp(key, 'positionCurrent')
                subindexedValuesNodes = currentNode.getElementsByTagName('SubindexedValues');
                for j = 0:subindexedValuesNodes.getLength-1
                    subindexedNode = subindexedValuesNodes.item(j);

                    if strcmp(char(subindexedNode.getAttribute('index')), 'ZAxis')
                        siv = subindexedNode.getElementsByTagName('SubindexedValue');
                        if siv.getLength > 0
                            position = str2num_local(siv.item(0).getAttribute('value'));
                            break;
                        end
                    end
                end
            end

            % --- micronsPerPixel (X/Y) ---
            if strcmp(key, 'micronsPerPixel')

                % 1) IndexedValue descendants
                idxNodes = currentNode.getElementsByTagName('IndexedValue');
                for j = 0:idxNodes.getLength-1
                    idxNode = idxNodes.item(j);
                    axis_name = char(idxNode.getAttribute('index'));

                    if ~isempty(axis_name) && idxNode.hasAttribute('value')
                        v = str2num_local(idxNode.getAttribute('value'));

                        if strcmp(axis_name, 'XAxis')
                            pixel_size_x = v;
                        elseif strcmp(axis_name, 'YAxis')
                            pixel_size_y = v;
                        end
                    end
                end

                % 2) SubindexedValue descendants
                subValNodes = currentNode.getElementsByTagName('SubindexedValue');
                for j = 0:subValNodes.getLength-1
                    svNode = subValNodes.item(j);

                    axis_name = '';
                    if svNode.hasAttribute('index')
                        axis_name = char(svNode.getAttribute('index'));
                    else
                        parent = svNode.getParentNode();
                        if ~isempty(parent) && parent.hasAttribute('index')
                            axis_name = char(parent.getAttribute('index'));
                        end
                    end

                    if ~isempty(axis_name) && svNode.hasAttribute('value')
                        v = str2num_local(svNode.getAttribute('value'));

                        if strcmp(axis_name, 'XAxis')
                            pixel_size_x = v;
                        elseif strcmp(axis_name, 'YAxis')
                            pixel_size_y = v;
                        end
                    end
                end

                % 3) Attributs directs sur PVStateValue
                if currentNode.hasAttribute('index') && currentNode.hasAttribute('value')
                    axis_name = char(currentNode.getAttribute('index'));
                    v = str2num_local(currentNode.getAttribute('value'));

                    if strcmp(axis_name, 'XAxis')
                        pixel_size_x = v;
                    elseif strcmp(axis_name, 'YAxis')
                        pixel_size_y = v;
                    end
                end
            end
        end

        %% === Durée d’enregistrement + absoluteTime globaux ===
        frameNodesGlobal = xmlDoc.getElementsByTagName('Frame');
        nFramesGlobal = frameNodesGlobal.getLength;
        abs_times_global = nan(1, nFramesGlobal);

        if nFramesGlobal > 0
            t_min = inf;
            t_max = -inf;
            have_time = false;

            for f = 0:nFramesGlobal-1
                frameNode = frameNodesGlobal.item(f);

                if frameNode.hasAttribute('absoluteTime')
                    t = str2num_local(frameNode.getAttribute('absoluteTime'));
                    abs_times_global(f+1) = t;

                    if ~isnan(t)
                        have_time = true;
                        if t < t_min, t_min = t; end
                        if t > t_max, t_max = t; end
                    end
                end
            end

            if have_time
                if t_max > t_min
                    duree_s = t_max - t_min;
                else
                    duree_s = 0;
                end
                time_minutes = duree_s / 60;
            end
        end

        % Fallback si aucun absoluteTime exploitable
        if isnan(time_minutes)
            segmentsNode = xmlDoc.getElementsByTagName('Segments').item(0);
            if ~isempty(segmentsNode) && segmentsNode.hasAttribute('Time')
                time_val = str2num_local(segmentsNode.getAttribute('Time')); % secondes
                time_minutes = time_val / 60;
            end
        end

        %% === Nombre de plans Z + positions Z par plan si ZSeries ===
        seqNodes = xmlDoc.getElementsByTagName('Sequence');
        n_plans = 1;   % valeur par défaut

        for s = 0:seqNodes.getLength-1
            seqNode = seqNodes.item(s);

            if ~seqNode.hasAttribute('type')
                continue;
            end

            seqType = char(seqNode.getAttribute('type'));
            if ~contains(seqType, 'ZSeries')
                continue;
            end

            frameNodesSeq = seqNode.getElementsByTagName('Frame');
            nFramesInSeq = frameNodesSeq.getLength;

            if nFramesInSeq == 0
                continue;
            end

            frame_index = nan(1, nFramesInSeq);
            z_focus_all = nan(1, nFramesInSeq);
            etl_raw_all = nan(1, nFramesInSeq);
            z_pos_all   = nan(1, nFramesInSeq);

            for f = 0:nFramesInSeq-1
                frameNode = frameNodesSeq.item(f);
                ii = f + 1;

                if frameNode.hasAttribute('index')
                    frame_index(ii) = str2double(char(frameNode.getAttribute('index')));
                else
                    frame_index(ii) = ii;
                end

                shardNodes = frameNode.getElementsByTagName('PVStateShard');
                shardNode = [];

                for k = 0:shardNodes.getLength-1
                    candidate = shardNodes.item(k);
                    if candidate.getElementsByTagName('PVStateValue').getLength > 0
                        shardNode = candidate;
                        break;
                    end
                end

                if isempty(shardNode)
                    continue;
                end

                framePV = shardNode.getElementsByTagName('PVStateValue');

                z_focus = NaN;
                etl_raw = NaN;

                for p = 0:framePV.getLength-1
                    pvNode = framePV.item(p);
                    kkey = char(pvNode.getAttribute('key'));

                    if ~strcmp(kkey, 'positionCurrent')
                        continue;
                    end

                    subindexedValuesNodes = pvNode.getElementsByTagName('SubindexedValues');
                    for j = 0:subindexedValuesNodes.getLength-1
                        subNode = subindexedValuesNodes.item(j);

                        if ~strcmp(char(subNode.getAttribute('index')), 'ZAxis')
                            continue;
                        end

                        sv = subNode.getElementsByTagName('SubindexedValue');
                        for t = 0:sv.getLength-1
                            svNode = sv.item(t);
                            val = str2num_local(svNode.getAttribute('value'));

                            descr = '';
                            if svNode.hasAttribute('description')
                                descr = char(svNode.getAttribute('description'));
                            end

                            subidx = '';
                            if svNode.hasAttribute('subindex')
                                subidx = char(svNode.getAttribute('subindex'));
                            end

                            if (~isempty(descr) && contains(descr, 'Z Focus')) || strcmp(subidx, '0')
                                z_focus = val;
                            elseif (~isempty(descr) && contains(descr, 'Optotune')) || strcmp(subidx, '1')
                                etl_raw = val;
                            end
                        end
                    end
                end

                if ~isnan(etl_raw) && abs(etl_raw) < 1e-6
                    etl_raw = 0;
                end

                z_focus_all(ii) = z_focus;
                etl_raw_all(ii) = etl_raw;

                if ~isnan(z_focus)
                    if isnan(etl_raw)
                        etl_raw = 0;
                    end
                    z_pos_all(ii) = z_focus + etl_raw / 1000;
                end
            end

            n_plans = nFramesInSeq;
            position = z_pos_all;
            break;
        end

        %% === Inférence du délai inter-plan et du sampling rate par plan ===
        abs_times = abs_times_global(~isnan(abs_times_global));

        if ~isnan(sampling_rate) && n_plans > 0
            if n_plans == 1
                % Pas de déplacement entre plans
                sampling_rate_per_plane = sampling_rate;
                interplane_delay_s = 0;

            else
                % 1) Estimation directe du sampling rate par plan
                if numel(abs_times) > n_plans
                    dt_same_plane = abs_times(1+n_plans:end) - abs_times(1:end-n_plans);
                    dt_same_plane = dt_same_plane(dt_same_plane > 0);

                    if ~isempty(dt_same_plane)
                        sampling_rate_per_plane = 1 / median(dt_same_plane);
                    end
                end

                % 2) Estimation du délai inter-plan depuis les frames consécutives
                if numel(abs_times) >= 2
                    dt_consecutive = diff(abs_times);
                    dt_consecutive = dt_consecutive(dt_consecutive > 0);

                    if ~isempty(dt_consecutive)
                        interplane_delay_s = median(dt_consecutive) - (1 / sampling_rate);

                        % évite les petites valeurs négatives dues au bruit numérique
                        if ~isnan(interplane_delay_s) && interplane_delay_s < 0
                            interplane_delay_s = max(interplane_delay_s, 0);
                        end
                    end
                end

                % === Affichage délai inter-plan ===
                if ~isnan(interplane_delay_s)
                    fprintf('Delai inter-plan estime : %.3f ms\n', interplane_delay_s * 1000);
                else
                    fprintf('Delai inter-plan non estime\n');
                end

                % 3) Fallback si dt_same_plane indisponible
                if isnan(sampling_rate_per_plane) && ~isnan(interplane_delay_s)
                    time_per_plane = n_plans * ((1 / sampling_rate) + interplane_delay_s);
                    sampling_rate_per_plane = 1 / time_per_plane;
                end
            end
        end

        %% === Pixel size final ===
        if ~isnan(pixel_size_x) && ~isnan(pixel_size_y)
            pixel_size = (pixel_size_x + pixel_size_y) / 2;
        elseif ~isnan(pixel_size_x)
            pixel_size = pixel_size_x;
        elseif ~isnan(pixel_size_y)
            pixel_size = pixel_size_y;
        else
            pixel_size = NaN;
        end

    catch ME
        fprintf('Erreur lors de la lecture du fichier : %s\n', ME.message);
    end
end