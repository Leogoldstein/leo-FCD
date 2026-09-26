function metrics = compute_all_basic_metrics( ...
    data, ...
    m, ...
    sampling_rate, ...
    include_electroporated_cells, ...
    show_burst_viewer, ...
    burst_options)

%COMPUTE_ALL_BASIC_METRICS
%
% Calcule les metriques par plan (GCaMP et electroporated).
% Les bursts sont definis en deux temps, sans signal deconvolue :
%   1) enveloppe de fluorescence positive lissee dans chaque segment valide;
%   2) hysteresis (seuil d'entree haut, seuil de sortie bas), fusion < 300 ms;
%   3) validation : duree >= 3 s, >= 5 pics du raster d'origine
%      repartis sur >= 2 s. Aucun second seuil de SNR/proeminence :
%      les pics ont deja ete valides par la detection initiale.
%
% Avant les bursts seulement : interpolation LINEAIRE des bad frames
% internes encadrees par deux frames valides. Aucune extrapolation aux
% extremites et aucune interpolation a travers un NaN hors bad frames.
% Les pics du raster situes sur les bad frames restent exclus ; les
% frequences, IEI et durees valides restent bases sur les donnees originales.
% Les matrices originales de data ne sont jamais modifiees.
%
% Le signal DF/F et les seuils de peak_detection sont reutilises tels quels.
% Les deux seules metriques de bursts conservees sont :
%   - proportion de cellules avec au moins un burst;
%   - nombre moyen de bursts par cellule.
% Les intervalles des bursts restent internes pour la visionneuse.
% show_burst_viewer (arg. 5) : visionneuse lecture seule, defaut false.
% burst_options (arg. 6) : parametres configurables, sauves dans metrics.
%

    %==============================================================%
    % Options
    %==============================================================%
    if nargin < 4 || ...
            isempty(include_electroporated_cells)

        include_electroporated_cells = ...
            '1';
    end

    if nargin < 5 || isempty(show_burst_viewer)
        show_burst_viewer = false; % Pas de GUI pendant les traitements batch.
    end

    validateattributes(show_burst_viewer, {'logical', 'numeric'}, ...
        {'scalar'}, mfilename, 'show_burst_viewer', 5);
    show_burst_viewer = logical(show_burst_viewer);

    if nargin < 6 || isempty(burst_options)
        burst_options = struct();
    end
    burst_options = normalize_burst_options(burst_options);


    include_electroporated_cells = ...
        char(string(include_electroporated_cells));


    process_electroporated = ...
        strcmp( ...
            include_electroporated_cells, ...
            '1');


    %==============================================================%
    % Initialisation
    %==============================================================%
    metrics = ...
        struct();


    metrics.valid = ...
        false;

    metrics.burst_options = burst_options;


    metrics.gcamp_plane = ...
        struct( ...
            'activity', ...
            empty_branch_metrics());


    metrics.electroporated_plane = ...
        struct( ...
            'activity', ...
            empty_branch_metrics());


    %==============================================================%
    % GCaMP activity
    %==============================================================%
    gcamp_metrics = ...
        compute_branch_metrics_by_plane( ...
            data, ...
            'gcamp_plane', ...
            m, ...
            sampling_rate, ...
            'DF_gcamp_by_plane', ...
            'Raster_gcamp_by_plane', ...
            'thresholds_gcamp_by_plane', ...
            'noise_est_gcamp_by_plane', ...
            burst_options);


    if ~gcamp_metrics.valid
        return;
    end


    metrics.valid = ...
        true;


    metrics.gcamp_plane.activity = ...
        gcamp_metrics;


    %==============================================================%
    % Electroporated / mTOR activity
    %==============================================================%
    if process_electroporated

        electroporated_metrics = ...
            compute_branch_metrics_by_plane( ...
                data, ...
                'electroporated_plane', ...
                m, ...
                sampling_rate, ...
                'DF_electroporated_by_plane', ...
                'Raster_electroporated_by_plane', ...
                'thresholds_electroporated_by_plane', ...
                'noise_est_electroporated_by_plane', ...
                burst_options);

    else

        electroporated_metrics = ...
            empty_branch_metrics();
    end


    metrics.electroporated_plane.activity = ...
        electroporated_metrics;

    % Une seule fenetre pour toutes les populations et tous les plans.
    if show_burst_viewer && usejava('awt')
        show_burst_metrics_viewer(data, m, sampling_rate, metrics);
    end
end


%==================================================================%
% Calcul d'une branche, plan par plan
%==================================================================%
function metrics = compute_branch_metrics_by_plane( ...
    data, ...
    branchName, ...
    m, ...
    sampling_rate, ...
    dfField, ...
    rasterField, ...
    thresholdField, ...
    noiseField, ...
    burst_options)

    metrics = ...
        empty_branch_metrics();


    has_data = ...
        has_nonempty_plane_field_nested( ...
            data, ...
            branchName, ...
            dfField, ...
            m) && ...
        has_nonempty_plane_field_nested( ...
            data, ...
            branchName, ...
            rasterField, ...
            m);


    if ~has_data
        return;
    end


    DF_planes = ...
        get_planes_nested( ...
            data, ...
            branchName, ...
            m, ...
            dfField);


    Raster_planes = ...
        get_planes_nested( ...
            data, ...
            branchName, ...
            m, ...
            rasterField);

    Threshold_planes = ...
        get_planes_nested( ...
            data, ...
            branchName, ...
            m, ...
            thresholdField);

    Noise_planes = get_planes_nested( ...
        data, branchName, m, noiseField);


    nPlanes = ...
        max( ...
            numel(DF_planes), ...
            numel(Raster_planes));


    metrics.nCells_by_plane = ...
        cell(1, nPlanes);

    metrics.nFrames_by_plane = ...
        cell(1, nPlanes);

    metrics.nValidFrames_by_plane = ...
        cell(1, nPlanes);

    metrics.nBadFrames_by_plane = ...
        cell(1, nPlanes);

    metrics.duration_min_by_plane = ...
        cell(1, nPlanes);

    metrics.freq_by_plane = ...
        cell(1, nPlanes);

    metrics.intervals_ms_by_plane = ...
        cell(1, nPlanes);

    % Deux seules metriques de bursts exportees par plan.
    metrics.burst_cell_proportion_by_plane = ...
        cell(1, nPlanes);

    metrics.mean_bursts_per_cell_by_plane = ...
        cell(1, nPlanes);

    % Interne uniquement : necessaire a la visionneuse.
    % {p}{c} = [frame_debut, frame_fin], une ligne par burst.
    metrics.burst_intervals_by_plane = cell(1, nPlanes);


    %==============================================================%
    % Plans
    %==============================================================%
    for p = 1:nPlanes

        DF = [];
        Raster = [];
        thresholds = [];
        noise_est = [];


        if p <= numel(DF_planes)

            DF = ...
                DF_planes{p};
        end


        if p <= numel(Raster_planes)

            Raster = ...
                Raster_planes{p};
        end


        if p <= numel(Threshold_planes)
            thresholds = Threshold_planes{p};
        end

        if p <= numel(Noise_planes)
            noise_est = Noise_planes{p};
        end

        if isempty(DF) || ...
                isempty(Raster)

            continue;
        end


        [DF, Raster] = ...
            align_data( ...
                DF, ...
                Raster);


        if isempty(DF) || ...
                isempty(Raster)

            continue;
        end


        metrics.valid = ...
            true;


        nFrames = ...
            size(Raster, 2);


        bad_frame_mask = ...
            get_bad_seg_mask( ...
                data, ...
                m, ...
                p, ...
                nFrames);


        nBadFrames = ...
            nnz(bad_frame_mask);


        nValidFrames = ...
            nFrames - ...
            nBadFrames;


        if isfinite(sampling_rate) && ...
                sampling_rate > 0

            duration_min = ...
                nValidFrames / ...
                sampling_rate / ...
                60;

        else

            duration_min = ...
                NaN;
        end


        %==========================================================%
        % Informations du plan
        %==========================================================%
        metrics.nCells_by_plane{p} = ...
            size(Raster, 1);


        metrics.nFrames_by_plane{p} = ...
            nFrames;


        metrics.nBadFrames_by_plane{p} = ...
            nBadFrames;


        metrics.nValidFrames_by_plane{p} = ...
            nValidFrames;


        metrics.duration_min_by_plane{p} = ...
            duration_min;


        %==========================================================%
        % Frequency
        %==========================================================%
        metrics.freq_by_plane{p} = ...
            compute_frequency_from_raster( ...
                Raster, ...
                sampling_rate, ...
                bad_frame_mask);


        %==========================================================%
        % Inter-event intervals
        %==========================================================%
        metrics.intervals_ms_by_plane{p} = ...
            compute_inter_event_intervals_from_raster( ...
                Raster, ...
                sampling_rate, ...
                bad_frame_mask);


        %==========================================================%
        % Bursts
        %==========================================================%
        [ ...
            burst_cell_proportion, ...
            mean_bursts_per_cell, ...
            burst_intervals ...
        ] = ...
            compute_burst_metrics_from_raster( ...
                Raster, ...
                DF, ...
                thresholds, ...
                noise_est, ...
                sampling_rate, ...
                bad_frame_mask, ...
                burst_options);


        metrics.burst_cell_proportion_by_plane{p} = ...
            burst_cell_proportion;


        metrics.mean_bursts_per_cell_by_plane{p} = ...
            mean_bursts_per_cell;


        metrics.burst_intervals_by_plane{p} = ...
            burst_intervals;
    end
end


%==================================================================%
% Frequency
%==================================================================%
function freq_per_cell_per_min = compute_frequency_from_raster( ...
    Raster, ...
    sampling_rate, ...
    bad_frame_mask)

    if isempty(Raster) || ...
            ~isfinite(sampling_rate) || ...
            sampling_rate <= 0

        freq_per_cell_per_min = ...
            [];

        return;
    end


    Raster = ...
        Raster ~= 0;


    [nCells, nFrames] = ...
        size(Raster);


    if nargin < 3 || ...
            isempty(bad_frame_mask)

        bad_frame_mask = ...
            false(1, nFrames);

    else

        bad_frame_mask = ...
            logical( ...
                bad_frame_mask(:).');


        if numel(bad_frame_mask) < nFrames

            bad_frame_mask( ...
                end + 1:nFrames) = ...
                false;

        elseif numel(bad_frame_mask) > nFrames

            bad_frame_mask = ...
                bad_frame_mask(1:nFrames);
        end
    end


    nValidFrames = ...
        nFrames - ...
        nnz(bad_frame_mask);


    duration_min = ...
        nValidFrames / ...
        sampling_rate / ...
        60;


    if duration_min <= 0

        freq_per_cell_per_min = ...
            nan(nCells, 1);

        return;
    end


    valid_frames = ...
        ~bad_frame_mask;


    nEvents = ...
        sum( ...
            Raster(:, valid_frames), ...
            2);


    freq_per_cell_per_min = ...
        nEvents ./ ...
        duration_min;
end


%==================================================================%
% Inter-event intervals
%==================================================================%
function intervals_ms = ...
    compute_inter_event_intervals_from_raster( ...
        Raster, ...
        sampling_rate, ...
        bad_frame_mask)

    intervals_ms = [];


    if isempty(Raster) || ...
            ~isfinite(sampling_rate) || ...
            sampling_rate <= 0

        return;
    end


    Raster = ...
        Raster ~= 0;


    [nCells, nFrames] = ...
        size(Raster);


    %==============================================================%
    % Bad frames
    %==============================================================%
    if nargin < 3 || ...
            isempty(bad_frame_mask)

        bad_frame_mask = ...
            false(1, nFrames);

    else

        bad_frame_mask = ...
            logical( ...
                bad_frame_mask(:).');


        if numel(bad_frame_mask) < nFrames

            bad_frame_mask( ...
                end + 1:nFrames) = ...
                false;

        elseif numel(bad_frame_mask) > nFrames

            bad_frame_mask = ...
                bad_frame_mask(1:nFrames);
        end
    end


    valid_frame_mask = ...
        ~bad_frame_mask;


    %==============================================================%
    % Segments continus valides
    %==============================================================%
    valid_transition = ...
        diff( ...
            [ ...
                false, ...
                valid_frame_mask, ...
                false ...
            ]);


    segment_starts = ...
        find( ...
            valid_transition == 1);


    segment_ends = ...
        find( ...
            valid_transition == -1) - ...
        1;


    %==============================================================%
    % Cellules
    %==============================================================%
    for c = 1:nCells

        for s = 1:numel(segment_starts)

            first_frame = ...
                segment_starts(s);


            last_frame = ...
                segment_ends(s);


            event_frames = ...
                find( ...
                    Raster( ...
                        c, ...
                        first_frame:last_frame));


            if numel(event_frames) < 2
                continue;
            end


            event_frames = ...
                event_frames + ...
                first_frame - ...
                1;


            cell_intervals = ...
                diff(event_frames) ./ ...
                sampling_rate .* ...
                1000;


            intervals_ms = ...
                [ ...
                    intervals_ms; ...
                    cell_intervals(:) ...
                ]; %#ok<AGROW>
        end
    end


    intervals_ms = ...
        intervals_ms( ...
            isfinite(intervals_ms));
end


%==================================================================%
% Bursts : enveloppe -> hysteresis -> fusion -> validation
%==================================================================%
function [ ...
    burst_cell_proportion, ...
    mean_bursts_per_cell, ...
    burst_intervals_by_cell] = ...
    compute_burst_metrics_from_raster( ...
        Raster, DF, thresholds, noise_est, ...
        sampling_rate, bad_frame_mask, opts)

    burst_cell_proportion = NaN;
    mean_bursts_per_cell = NaN;
    burst_intervals_by_cell = {};

    if isempty(Raster) || isempty(DF) || ...
            ~isscalar(sampling_rate) || ...
            ~isfinite(sampling_rate) || sampling_rate <= 0
        return;
    end

    Raster = Raster ~= 0;
    [nCells, nFrames] = size(Raster);
    burst_intervals_by_cell = repmat({zeros(0, 2)}, nCells, 1);

    if isempty(bad_frame_mask)
        bad_frame_mask = false(1, nFrames);
    end
    bad_frame_mask = logical(bad_frame_mask(:).');
    if numel(bad_frame_mask) < nFrames
        bad_frame_mask(end+1:nFrames) = false;
    else
        bad_frame_mask = bad_frame_mask(1:nFrames);
    end

    valid_frames = ~bad_frame_mask;
    if ~any(valid_frames)
        return;
    end

    % Nombre de bursts par cellule.
    % NaN = cellule non evaluable (bruit/seuil absent).
    % 0   = cellule evaluable mais sans burst.
    burst_count_per_cell = nan(nCells, 1);

    % Seuil et bruit SPECIFIQUES a chaque cellule : ceux du peak tuner.
    % Le seuil est conserve ici uniquement pour garder exactement la meme
    % condition d'evaluabilite qu'avant la simplification des sorties.
    if ~isnumeric(thresholds) || numel(thresholds) ~= nCells
        thresholds = nan(nCells, 1);
    else
        thresholds = double(thresholds(:));
    end

    if ~isnumeric(noise_est) || numel(noise_est) ~= nCells
        noise_est = nan(nCells, 1);
    else
        noise_est = double(noise_est(:));
    end

    % Fenetre impaire pour un lissage temporel centre (pas de deconvolution).
    smooth_frames = max(1, round(opts.envelope_window_s*sampling_rate));
    if mod(smooth_frames, 2) == 0
        smooth_frames = smooth_frames + 1;
    end

    for c = 1:nCells

        original_x = double(DF(c, :));

        % Corriger la trace pour les BURSTS uniquement.
        [x, ~, unfilled_bad] = interpolate_burst_bad_frames( ...
            original_x, bad_frame_mask);

        sigma = noise_est(c);
        threshold = thresholds(c);

        if ~isfinite(sigma) || sigma <= 0 || ~isfinite(threshold)
            continue;
        end

        % A partir d'ici la cellule est evaluable : aucun burst = 0.
        burst_count_per_cell(c) = 0;

        cell_valid = ~unfilled_bad & isfinite(x);

        % Les pics originaux presents sur les bad frames restent exclus.
        original_event_valid = valid_frames & isfinite(original_x);
        n_valid_events = nnz(Raster(c, :) & original_event_valid);

        if n_valid_events == 0
            continue;
        end

        d = diff([false, cell_valid, false]);
        seg_start = find(d == 1);
        seg_end = find(d == -1)-1;
        accepted = zeros(0, 2);

        % Une seule enveloppe par cellule, segmentee aux NaN.
        envelope_all = compute_burst_envelope(x, sigma, smooth_frames);

        for seg = 1:numel(seg_start)

            a = seg_start(seg);
            b = seg_end(seg);

            if b-a+1 < 2
                continue;
            end

            envelope = envelope_all(a:b);

            % Hysteresis : une zone au-dessus du seuil BAS est candidate
            % seulement si elle contient au moins un passage au seuil HAUT.
            low = envelope >= opts.offset_snr;
            high = envelope >= opts.onset_snr;
            dLow = diff([false, low, false]);
            starts = find(dLow == 1);
            ends = find(dLow == -1)-1;
            candidates = zeros(0, 2);

            for r = 1:numel(starts)

                u = starts(r);
                v = ends(r);

                if ~any(high(u:v))
                    continue;
                end

                % Bornes fractionnaires au franchissement du seuil BAS.
                left = a+u-1;
                right = a+v-1;

                if u > 1
                    previous = envelope(u-1);
                    current = envelope(u);

                    if current > previous
                        left = (a+u-2) + ...
                            (opts.offset_snr-previous)/(current-previous);
                    end
                end

                if v < numel(envelope)
                    current = envelope(v);
                    following = envelope(v+1);

                    if current > following
                        right = (a+v-1) + ...
                            (current-opts.offset_snr)/(current-following);
                    end
                end

                candidates(end+1, :) = [left right]; %#ok<AGROW>
            end

            % Fusion avant validation.
            merged = merge_burst_intervals( ...
                candidates, sampling_rate, opts.merge_gap_s);

            for k = 1:size(merged, 1)

                left = merged(k, 1);
                right = merged(k, 2);

                episode_duration = ...
                    (right-left)/sampling_rate;

                if episode_duration < opts.min_burst_duration_s
                    continue;
                end

                % Les pics proviennent exclusivement du Raster sauvegarde.
                peaks = find(Raster(c, a:b)) + a-1;
                peaks = peaks( ...
                    peaks >= left & ...
                    peaks <= right & ...
                    original_event_valid(peaks));

                if numel(peaks) < opts.min_peaks
                    continue;
                end

                peak_span_s = ...
                    (peaks(end)-peaks(1))/sampling_rate;

                if peak_span_s < opts.min_peak_span_s
                    continue;
                end

                accepted(end+1, :) = [left right]; %#ok<AGROW>
            end
        end

        accepted = sortrows(accepted, [1 2]);

        burst_intervals_by_cell{c} = ...
            accepted;

        burst_count_per_cell(c) = ...
            size(accepted, 1);
    end

    % Resume du plan sur les cellules effectivement evaluables.
    valid_cells = ...
        isfinite(burst_count_per_cell);

    if any(valid_cells)

        counts = ...
            burst_count_per_cell(valid_cells);

        % Fraction entre 0 et 1 de cellules avec au moins un burst.
        burst_cell_proportion = ...
            mean(counts >= 1);

        % Nombre moyen de bursts par cellule sur l'enregistrement.
        mean_bursts_per_cell = ...
            mean(counts);
    end
end

% Meme calcul d'enveloppe pour la detection et son affichage.
% x doit avoir ete interpole sur les bad frames interpolables.
% Le lissage ne traverse jamais une lacune NaN/non-interpolable.
function envelope = compute_burst_envelope(x, sigma, smooth_frames)
    envelope = nan(size(x));
    if ~isfinite(sigma) || sigma <= 0
        return;
    end
    valid = isfinite(x);
    d = diff([false valid false]);
    starts = find(d == 1);
    ends = find(d == -1)-1;
    for s = 1:numel(starts)
        idx = starts(s):ends(s);
        envelope(idx) = movmean(max(x(idx), 0)/sigma, smooth_frames);
    end
end

% Interpolation lineaire des SEULES bad frames, sur une copie de la trace.
% Les deux bornes doivent etre des frames non-bad avec signal fini.
% Une bad frame non encadree reste invalide : pas d'extrapolation.
% Les NaN hors bad frames ne sont jamais utilises comme points d'ancrage.
function [x_clean, interpolated, unfilled_bad] = ...
    interpolate_burst_bad_frames(x, bad_frame_mask)

    x_clean = double(x(:).');
    nFrames = numel(x_clean);
    bad_frame_mask = logical(bad_frame_mask(:).');
    if numel(bad_frame_mask) ~= nFrames
        error('Le masque des bad frames et la trace ont des tailles differentes.');
    end

    interpolated = false(1, nFrames);
    if ~any(bad_frame_mask)
        unfilled_bad = bad_frame_mask;
        return;
    end

    transitions = diff([false, bad_frame_mask, false]);
    run_starts = find(transitions == 1);
    run_ends = find(transitions == -1) - 1;
    for r = 1:numel(run_starts)
        first = run_starts(r);
        last = run_ends(r);
        before = first - 1;
        after = last + 1;

        if before < 1 || after > nFrames || ...
                ~isfinite(x_clean(before)) || ~isfinite(x_clean(after))
            continue;
        end

        missing = first:last;
        x_clean(missing) = x_clean(before) + ...
            (x_clean(after)-x_clean(before)) * ...
            ((missing-before)/(after-before));
        interpolated(missing) = true;
    end

    unfilled_bad = bad_frame_mask & ~interpolated;
    x_clean(unfilled_bad) = NaN;
end

% Fusion par bornes reelles d'intersection avec le seuil, et NON par
% distance entre les pics. Appeler uniquement a l'interieur d'un segment
% continu apres interpolation, sans NaN ni bad frames non interpolees.
function merged = merge_burst_intervals(intervals, sampling_rate, gap_s)
    merged = zeros(0, 2);
    if isempty(intervals)
        return;
    end

    intervals = sortrows(intervals, [1, 2]);
    merged = intervals(1, :);
    max_gap_frames = gap_s * sampling_rate;
    for i = 2:size(intervals, 1)
        gap_frames = intervals(i, 1) - merged(end, 2);
        if gap_frames <= 0 || gap_frames < max_gap_frames
            merged(end, 2) = max(merged(end, 2), intervals(i, 2));
        else
            merged(end+1, :) = intervals(i, :); %#ok<AGROW>
        end
    end
end

% Aucune selection supplementaire des pics ici : la detection initiale
% constitue la seule etape de validation des pics du Raster.
% La fonction suivante ne calcule qu'une metrique descriptive a posteriori.
% Prominence topographique sur le signal DF/F : pour chaque pic, chercher
% de chaque cote le creux avant de rencontrer une fluorescence PLUS haute
% (ou la limite du candidat). La reference est le creux le plus HAUT des
% deux cotes. Ainsi une petite oscillation sur un grand transitoire garde
% une faible prominence, meme si son amplitude absolue est elevee.
function prominences = peak_prominences_from_trace(x, peaks, left, right)
    prominences = zeros(size(peaks));
    first_frame = max(1, ceil(left));
    last_frame = min(numel(x), floor(right));

    for i = 1:numel(peaks)
        pk = peaks(i);
        height = x(pk);
        valley_left = height;
        valley_right = height;

        for j = pk-1:-1:first_frame
            if x(j) > height
                break;
            end
            valley_left = min(valley_left, x(j));
        end
        for j = pk+1:last_frame
            if x(j) > height
                break;
            end
            valley_right = min(valley_right, x(j));
        end

        prominences(i) = max(0, height-max(valley_left, valley_right));
    end
end

% Calcul exact pour l'interpolation lineaire du temps au-dessus d'un
% seuil et de l'AUC au-dessus de ce seuil. Les integrales s'arretent
% aux limites valides et ne franchissent jamais un NaN/bad frame.
function [above_duration_s, auc] = integrate_above_threshold( ...
    x, threshold, left, right, sampling_rate, bad)

    above_duration_s = 0;
    auc = 0;
    n = numel(x);
    left = max(1, left);
    right = min(n, right);
    if ~isfinite(threshold) || ~isfinite(left) || ...
            ~isfinite(right) || right <= left
        above_duration_s = NaN;
        auc = NaN;
        return;
    end

    knots = unique([left, ceil(left):floor(right), right]);
    for k = 1:numel(knots)-1
        a = knots(k);
        b = knots(k+1);
        if b <= a
            continue;
        end
        ya = burst_edge_y(x, bad, a);
        yb = burst_edge_y(x, bad, b);
        if ~isfinite(ya) || ~isfinite(yb)
            continue;
        end
        za = ya-threshold;
        zb = yb-threshold;
        dt = (b-a)/sampling_rate;
        if za >= 0 && zb >= 0
            above_duration_s = above_duration_s + dt;
            auc = auc + 0.5*(za+zb)*dt;
        elseif za > 0 && zb < 0
            frac = za/(za-zb);
            above_duration_s = above_duration_s + dt*frac;
            auc = auc + 0.5*za*dt*frac;
        elseif za < 0 && zb > 0
            frac = zb/(zb-za);
            above_duration_s = above_duration_s + dt*frac;
            auc = auc + 0.5*zb*dt*frac;
        end
    end
end

% Parametres empiriques a calibrer sur des episodes annotes.
% Conserver les options dans metrics pour reproductibilite.
function opts = normalize_burst_options(opts)
    if ~isstruct(opts) || ~isscalar(opts)
        error('burst_options doit etre une structure scalaire.');
    end
    % Anciennes options eventuellement transmises par un appelant : ignorees.
    % Elles sont retirees des options sauvegardees pour eviter de suggerer
    % qu'un seuil additionnel est applique lors du calcul des bursts.
    obsolete = {'min_peak_snr', 'min_strong_peaks', ...
        'min_support_peak_snr', 'min_secondary_peak_snr', ...
        'min_support_peak_prominence_snr', ...
        'min_strong_peak_prominence_snr', ...
        'min_peak_separation_s', 'min_valley_fraction'};
    present = intersect(obsolete, fieldnames(opts));
    if ~isempty(present)
        opts = rmfield(opts, present);
    end

    defaults = struct( ...
        'envelope_window_s', 1, ...
        'onset_snr', 3, ...
        'offset_snr', 2, ...
        'merge_gap_s', 0.3, ...
        'min_burst_duration_s', 3.0, ...
        'min_peaks', 5, ...
        'min_peak_span_s', 2.0);
    keys = fieldnames(defaults);
    for k = 1:numel(keys)
        key = keys{k};
        if ~isfield(opts, key) || isempty(opts.(key))
            opts.(key) = defaults.(key);
        end
        validateattributes(opts.(key), {'numeric'}, ...
            {'scalar', 'real', 'finite', 'positive'}, ...
            mfilename, ['burst_options.' key]);
    end
    validateattributes(opts.min_peaks, {'numeric'}, ...
        {'integer', '>=', 2}, mfilename, 'burst_options.min_peaks');
    if opts.onset_snr <= opts.offset_snr
        error('burst_options.onset_snr doit depasser offset_snr.');
    end
end

%==================================================================%
% Visionneuse de bursts : tracé, pics, seuil, curseur cellule
%==================================================================%
function show_burst_metrics_viewer(data, m, sampling_rate, metrics)

    if ~isscalar(sampling_rate) || ~isfinite(sampling_rate) || ...
            sampling_rate <= 0
        return;
    end

    % Construire la liste des plans réellement disponibles, sans relancer
    % la détection : les segments rouges proviennent des INTERVALLES
    % calculés ci-dessus pour les métriques elles-mêmes.
    views = struct('label', {}, 'DF', {}, 'Raster', {}, ...
        'thresholds', {}, 'noise_est', {}, 'bad', {}, 'bursts', {});
    branches = {'gcamp_plane', 'electroporated_plane'};
    names = {'GCaMP', 'Electroporated'};

    for ib = 1:numel(branches)
        branch = branches{ib};
        activity = metrics.(branch).activity;
        if ~activity.valid
            continue;
        end

        prefix = names{ib};
        if ib == 1
            dfName = 'DF_gcamp_by_plane';
            rasterName = 'Raster_gcamp_by_plane';
            thresholdName = 'thresholds_gcamp_by_plane';
            noiseName = 'noise_est_gcamp_by_plane';
        else
            dfName = 'DF_electroporated_by_plane';
            rasterName = 'Raster_electroporated_by_plane';
            thresholdName = 'thresholds_electroporated_by_plane';
            noiseName = 'noise_est_electroporated_by_plane';
        end

        dfPlanes = get_planes_nested(data, branch, m, dfName);
        rasterPlanes = get_planes_nested(data, branch, m, rasterName);
        thresholdPlanes = get_planes_nested(data, branch, m, thresholdName);
        noisePlanes = get_planes_nested(data, branch, m, noiseName);

        nPlanes = min(numel(dfPlanes), numel(rasterPlanes));
        for p = 1:nPlanes
            DF = dfPlanes{p};
            Raster = rasterPlanes{p};
            if isempty(DF) || isempty(Raster)
                continue;
            end
            [DF, Raster] = align_data(DF, Raster);
            if isempty(DF) || isempty(Raster)
                continue;
            end

            nCells = size(DF, 1);
            thr = nan(nCells, 1);
            if numel(thresholdPlanes) >= p && ...
                    isnumeric(thresholdPlanes{p}) && ...
                    numel(thresholdPlanes{p}) == nCells
                thr = double(thresholdPlanes{p}(:));
            end
            noise = nan(nCells, 1);
            if numel(noisePlanes) >= p && ...
                    isnumeric(noisePlanes{p}) && ...
                    numel(noisePlanes{p}) == nCells
                noise = double(noisePlanes{p}(:));
            end

            bursts = cell(nCells, 1);
            if numel(activity.burst_intervals_by_plane) >= p && ...
                    iscell(activity.burst_intervals_by_plane{p}) && ...
                    numel(activity.burst_intervals_by_plane{p}) == nCells
                bursts = activity.burst_intervals_by_plane{p};
            end

            v = numel(views) + 1;
            views(v).label = sprintf('%s | Plan %d', prefix, p-1);
            views(v).DF = DF;
            views(v).Raster = logical(Raster);
            views(v).thresholds = thr;
            views(v).noise_est = noise;
            views(v).bad = ...
                get_bad_seg_mask( ...
                    data, ...
                    m, ...
                    p, ...
                    size(DF, 2));
            views(v).bursts = bursts;
        end
    end

    if isempty(views)
        return;
    end

    fig = figure( ...
        'Name', sprintf('Burst viewer | recording %d', m), ...
        'NumberTitle', 'off', 'Color', 'w', ...
        'Units', 'normalized', 'Position', [0.10 0.10 0.80 0.78], ...
        'MenuBar', 'none', 'ToolBar', 'figure');

    statusLabel = uicontrol(fig, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.075 0.89 0.89 0.095], ...
        'BackgroundColor', 'w', 'HorizontalAlignment', 'left', ...
        'FontSize', 9, 'String', '');

    axTrace = axes('Parent', fig, 'Units', 'normalized', ...
        'Position', [0.075 0.51 0.89 0.35]);
    axEnvelope = axes('Parent', fig, 'Units', 'normalized', ...
        'Position', [0.075 0.20 0.89 0.21]);
    linkaxes([axTrace, axEnvelope], 'x');

    labels = {views.label};
    planMenu = uicontrol(fig, 'Style', 'popupmenu', ...
        'Units', 'normalized', 'Position', [0.075 0.06 0.39 0.075], ...
        'String', labels, 'Value', 1, 'Callback', @change_plan);

    cellSlider = uicontrol(fig, 'Style', 'slider', ...
        'Units', 'normalized', 'Position', [0.51 0.08 0.37 0.045], ...
        'Min', 1, 'Max', 2, 'Value', 1, 'Callback', @change_cell);

    cellLabel = uicontrol(fig, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.89 0.065 0.08 0.055], ...
        'BackgroundColor', 'w', 'HorizontalAlignment', 'left', ...
        'String', '1 / 1');

    currentPlan = 1;
    currentCell = 1;
    configure_slider();
    redraw();

    % Bloquer le traitement (notamment la fonction mere) tant que
    % l'utilisateur n'a pas ferme cette figure. waitfor continue de
    % traiter les callbacks du menu et du slider pendant l'attente.
    % Fermer normalement la figure la supprime et debloque waitfor.
    waitfor(fig);

    function change_plan(~, ~)
        currentPlan = get(planMenu, 'Value');
        currentCell = 1;
        configure_slider();
        redraw();
    end

    function change_cell(~, ~)
        n = size(views(currentPlan).DF, 1);
        currentCell = max(1, min(n, round(get(cellSlider, 'Value'))));
        set(cellSlider, 'Value', currentCell);
        redraw();
    end

    function configure_slider()
        n = size(views(currentPlan).DF, 1);
        set(cellSlider, 'Min', 1, 'Max', max(2, n), ...
            'Value', currentCell, ...
            'SliderStep', [1/max(1, n-1), min(1, 10/max(1, n-1))]);
        if n < 2
            set(cellSlider, 'Enable', 'off');
        else
            set(cellSlider, 'Enable', 'on');
        end
        set(cellLabel, 'String', sprintf('%d / %d', currentCell, n));
    end

    function redraw()
        if ~isgraphics(fig) || ~isgraphics(axTrace) || ...
                ~isgraphics(axEnvelope)
            return;
        end
        view = views(currentPlan);
        c = currentCell;
        original_x = double(view.DF(c, :));
        [x, interpolated, unfilled_bad] = ...
            interpolate_burst_bad_frames(original_x, view.bad);
        bad = unfilled_bad | ~isfinite(x);
        visibleX = x;
        visibleX(bad) = NaN; % Seules les lacunes non interpolables coupent.
        t = (0:numel(x)-1) / sampling_rate;

        % Courbe EXACTEMENT identique a celle utilisee par l'hysteresis.
        smooth_frames = max(1, round( ...
            metrics.burst_options.envelope_window_s*sampling_rate));
        if mod(smooth_frames, 2) == 0
            smooth_frames = smooth_frames + 1;
        end
        envelope = compute_burst_envelope( ...
            x, view.noise_est(c), smooth_frames);

        cla(axTrace);
        hold(axTrace, 'on');
        plot(axTrace, t, visibleX, 'k-', 'LineWidth', 0.8);
        % Les frames interpolees ne sont pas des points observes.
        if any(interpolated)
            runs = diff([false, interpolated, false]);
            starts = find(runs == 1);
            ends = find(runs == -1)-1;
            for r = 1:numel(starts)
                idx = max(1, starts(r)-1):min(numel(x), ends(r)+1);
                plot(axTrace, t(idx), visibleX(idx), '--', ...
                    'Color', [0.55 0.55 0.55], 'LineWidth', 1.2);
            end
        end

        intervals = view.bursts{c};
        if ~isempty(intervals)
            for iburst = 1:size(intervals, 1)
                draw_red_interval(axTrace, x, bad, ...
                    intervals(iburst, :), sampling_rate);
            end
        end

        % Tous les pics du Raster sont valides ; aucun tri SNR supplementaire.
        pk = find(view.Raster(c, :) & ~view.bad & isfinite(original_x));
        in_burst = false(size(pk));
        for iburst = 1:size(intervals, 1)
            in_burst = in_burst | ...
                (pk >= intervals(iburst, 1) & pk <= intervals(iburst, 2));
        end
        plot(axTrace, t(pk(~in_burst)), x(pk(~in_burst)), ...
            'o', 'LineStyle', 'none', ...
            'Color', [0.53 0.68 0.86], 'MarkerSize', 4, 'LineWidth', 0.8);
        plot(axTrace, t(pk(in_burst)), x(pk(in_burst)), ...
            'o', 'LineStyle', 'none', ...
            'Color', [0.08 0.30 0.85], ...
            'MarkerFaceColor', [0.08 0.30 0.85], ...
            'MarkerSize', 5, 'LineWidth', 1);

        thr = view.thresholds(c);
        if isfinite(thr)
            yline(axTrace, thr, '--', 'Color', [0.15 0.52 0.80], ...
                'LineWidth', 1);
        end
        ylabel(axTrace, '\DeltaF/F');
        title(axTrace, sprintf('%s | Cellule %d | Fluorescence et bursts', ...
            view.label, c), 'Interpreter', 'none');
        xlim(axTrace, [0 max(1/sampling_rate, t(end))]);
        set(axTrace, 'XTickLabel', []);
        box(axTrace, 'off');
        hold(axTrace, 'off');

        % Deuxieme panneau : enveloppe lisse utilisee pour l'hysteresis,
        % avec les deux seuils exprimes en unites de bruit (sigma).
        cla(axEnvelope);
        hold(axEnvelope, 'on');
        plot(axEnvelope, t, envelope, '-', ...
            'Color', [0.30 0.24 0.65], 'LineWidth', 1.0);
        for iburst = 1:size(intervals, 1)
            draw_red_interval(axEnvelope, envelope, ~isfinite(envelope), ...
                intervals(iburst, :), sampling_rate);
        end
        yline(axEnvelope, metrics.burst_options.onset_snr, '--', ...
            'Color', [0.08 0.45 0.80], 'LineWidth', 1, ...
            'Label', 'Entree');
        yline(axEnvelope, metrics.burst_options.offset_snr, '--', ...
            'Color', [0.12 0.55 0.25], 'LineWidth', 1, ...
            'Label', 'Sortie');
        ylabel(axEnvelope, 'Enveloppe (\sigma)');
        xlabel(axEnvelope, 'Temps (s)');
        xlim(axEnvelope, [0 max(1/sampling_rate, t(end))]);
        box(axEnvelope, 'off');
        hold(axEnvelope, 'off');

        if ~isfinite(view.noise_est(c)) || view.noise_est(c) <= 0 || ...
                ~isfinite(view.thresholds(c))
            status_text = sprintf( ...
                '%s | bruit ou seuil de detection absent : bursts non calcules', ...
                view.label);
        else
            status_text = { ...
                sprintf('%d pics Raster | %d bursts | %d bad frames interpolees', ...
                    numel(pk), size(intervals, 1), nnz(interpolated)), ...
                sprintf(['Hysteresis : enveloppe %.2f s, entree %.1f sigma, ' ...
                    'sortie %.1f sigma | fusion < %.0f ms'], ...
                    metrics.burst_options.envelope_window_s, ...
                    metrics.burst_options.onset_snr, ...
                    metrics.burst_options.offset_snr, ...
                    1000*metrics.burst_options.merge_gap_s), ...
                sprintf(['Validation : >= %d pics du Raster | duree >= %.1f s ' ...
                    '| etalement >= %.1f s | aucun second seuil SNR'], ...
                    metrics.burst_options.min_peaks, ...
                    metrics.burst_options.min_burst_duration_s, ...
                    metrics.burst_options.min_peak_span_s) ...
            };
        end
        set(statusLabel, 'String', status_text);
        set(cellLabel, 'String', sprintf('%d / %d', c, size(view.DF, 1)));
    end
end

% Rouge UNIQUEMENT sur la portion de trace appartenant au burst.
% Les bornes fractionnaires correspondent au seuil BAS de l enveloppe.
function draw_red_interval(ax, x, bad, interval, sampling_rate)
    n = numel(x);
    left = max(1, interval(1));
    right = min(n, interval(2));
    if ~all(isfinite([left, right])) || right < left
        return;
    end

    idx = ceil(left):floor(right);
    xx = [left, double(idx), right];
    yy = nan(size(xx));
    if ~isempty(idx)
        yy(2:end-1) = x(idx);
        yy([false, bad(idx), false]) = NaN;
    end
    yy(1) = burst_edge_y(x, bad, left);
    yy(end) = burst_edge_y(x, bad, right);

    plot(ax, (xx-1)/sampling_rate, yy, 'r-', 'LineWidth', 2.2);
end

function y = burst_edge_y(x, bad, frame)
    a = floor(frame);
    b = ceil(frame);
    a = max(1, min(numel(x), a));
    b = max(1, min(numel(x), b));
    goodA = ~bad(a) && isfinite(x(a));
    goodB = ~bad(b) && isfinite(x(b));
    if goodA && goodB
        y = x(a) + (frame-a) * (x(b)-x(a));
    elseif goodA
        % Borne au contact d'une mauvaise frame : pas d'interpolation.
        y = x(a);
    elseif goodB
        y = x(b);
    else
        y = NaN;
    end
end

%==================================================================%
% Empty branch
%==================================================================%
function metrics = empty_branch_metrics()

    metrics = ...
        struct( ...
            'valid', false, ...
            'nCells_by_plane', {{}}, ...
            'nFrames_by_plane', {{}}, ...
            'nValidFrames_by_plane', {{}}, ...
            'nBadFrames_by_plane', {{}}, ...
            'duration_min_by_plane', {{}}, ...
            'freq_by_plane', {{}}, ...
            'intervals_ms_by_plane', {{}}, ...
            'burst_cell_proportion_by_plane', {{}}, ...
            'mean_bursts_per_cell_by_plane', {{}}, ...
            'burst_intervals_by_plane', {{}});
end


%==================================================================%
% Align data
%==================================================================%
function [DF, Raster] = align_data( ...
        DF, ...
        Raster)

    min_cells = ...
        min( ...
            size(DF, 1), ...
            size(Raster, 1));


    min_frames = ...
        min( ...
            size(DF, 2), ...
            size(Raster, 2));


    DF = ...
        DF( ...
            1:min_cells, ...
            1:min_frames);


    Raster = ...
        Raster( ...
            1:min_cells, ...
            1:min_frames);
end


%==================================================================%
% Get planes
%==================================================================%
function planes = get_planes_nested( ...
        data, ...
        branchName, ...
        m, ...
        fieldName)

    planes = {};


    if ~isfield(data, branchName) || ...
            ~isstruct(data.(branchName))

        return;
    end


    branch = ...
        data.(branchName);


    if ~isfield(branch, fieldName) || ...
            numel(branch.(fieldName)) < m || ...
            isempty(branch.(fieldName){m})

        return;
    end


    planes = ...
        branch.(fieldName){m};


    if ~iscell(planes)

        planes = ...
            {planes};
    end
end


function tf = has_nonempty_plane_field_nested( ...
        data, ...
        branchName, ...
        fieldName, ...
        m)

    tf = ...
        false;


    if ~isfield(data, branchName) || ...
            ~isstruct(data.(branchName))

        return;
    end


    branch = ...
        data.(branchName);


    if ~isfield(branch, fieldName)
        return;
    end


    if numel(branch.(fieldName)) < m || ...
            isempty(branch.(fieldName){m})

        return;
    end


    planes = ...
        branch.(fieldName){m};


    if ~iscell(planes)

        tf = ...
            ~isempty(planes);

        return;
    end


    for p = 1:numel(planes)

        if ~isempty(planes{p})

            tf = ...
                true;

            return;
        end
    end
end


%==================================================================%
% Bad segments -> masque logique du plan
%==================================================================%
function bad_frame_mask = get_bad_seg_mask( ...
        data, ...
        m, ...
        p, ...
        nFrames)

    bad_frame_mask = ...
        false(1, nFrames);

    if nargin < 4 || ...
            isempty(nFrames) || ...
            nFrames <= 0

        return;
    end

    if ~isstruct(data) || ...
            ~isfield(data, 'motion') || ...
            ~isstruct(data.motion) || ...
            ~isfield(data.motion, 'bad_segs_group') || ...
            ~iscell(data.motion.bad_segs_group) || ...
            numel(data.motion.bad_segs_group) < m || ...
            isempty(data.motion.bad_segs_group{m})

        return;
    end

    bad_segs_by_plane = ...
        data.motion.bad_segs_group{m};

    if ~iscell(bad_segs_by_plane)

        % Compatibilite ancien format monoplane.
        if p ~= 1
            return;
        end

        bad_segs = ...
            bad_segs_by_plane;

    else

        if numel(bad_segs_by_plane) < p
            return;
        end

        bad_segs = ...
            bad_segs_by_plane{p};
    end

    bad_frame_mask = ...
        convert_bad_segs_to_mask( ...
            bad_segs, ...
            nFrames);
end


function bad_frame_mask = convert_bad_segs_to_mask( ...
        bad_segs, ...
        nFrames)

    bad_frame_mask = ...
        false(1, nFrames);

    if isempty(bad_segs) || ...
            nFrames <= 0

        return;
    end

    if ~isnumeric(bad_segs)
        return;
    end

    bad_segs = ...
        double(bad_segs);

    if isvector(bad_segs) && ...
            numel(bad_segs) == 2

        bad_segs = ...
            reshape( ...
                bad_segs, ...
                1, ...
                2);
    end

    if size(bad_segs,2) < 2
        return;
    end

    bad_segs = ...
        bad_segs(:,1:2);

    for k = 1:size(bad_segs,1)

        first_frame = ...
            bad_segs(k,1);

        last_frame = ...
            bad_segs(k,2);

        if ~isfinite(first_frame) || ...
                ~isfinite(last_frame)

            continue;
        end

        first_frame = ...
            round(first_frame);

        last_frame = ...
            round(last_frame);

        if first_frame > last_frame

            tmp = first_frame;

            first_frame = ...
                last_frame;

            last_frame = ...
                tmp;
        end

        first_frame = ...
            max( ...
                1, ...
                first_frame);

        last_frame = ...
            min( ...
                nFrames, ...
                last_frame);

        if first_frame <= last_frame

            bad_frame_mask( ...
                first_frame:last_frame) = ...
                true;
        end
    end
end
