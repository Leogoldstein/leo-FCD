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
%   3) validation restrictive : duree >= 3 s, >= 5 pics distincts,
%      au moins 3 pics SNR amplitude >= 6 ET SNR prominence >= 2.5,
%      tous SNR amplitude >= 4.5 ET SNR prominence >= 1.5, et pics
%      repartis sur >= 2 secondes (pas un seul pic avec satellites).
%
% Avant les bursts seulement : interpolation LINEAIRE des bad frames
% internes encadrees par deux frames valides. Aucune extrapolation aux
% extremites et aucune interpolation a travers un NaN hors bad frames.
% Les pics du raster situes sur les bad frames restent exclus ; les
% frequences, IEI et durees valides restent bases sur les donnees originales.
% Les matrices originales de data ne sont jamais modifiees.
%
% Le signal DF/F et les seuils de peak_detection sont reutilises tels quels.
% AUC et duree au-dessus du seuil de detection restent des METRIQUES;
% ce seuil strict ne fragmente plus les episodes.
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

    metrics.burst_rate_by_plane = ...
        cell(1, nPlanes);

    metrics.burst_fraction_by_plane = ...
        cell(1, nPlanes);

    metrics.burst_size_by_plane = ...
        cell(1, nPlanes);

    metrics.burst_duration_s_by_plane = ...
        cell(1, nPlanes);

    metrics.burst_above_threshold_duration_s_by_plane = ...
        cell(1, nPlanes);

    metrics.burst_auc_by_plane = cell(1, nPlanes);
    metrics.burst_auc_snr_s_by_plane = cell(1, nPlanes);
    metrics.burst_peak_snr_by_plane = cell(1, nPlanes);
    metrics.burst_peak_prominence_snr_by_plane = cell(1, nPlanes);
    metrics.burst_significant_size_by_plane = cell(1, nPlanes);

    % Bornes des bursts, en indices de frames potentiellement fractionnaires.
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
            get_bad_frame_mask( ...
                data, ...
                m, ...
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
            burst_rate, ...
            burst_fraction, ...
            burst_size, ...
            burst_duration_s, ...
            burst_above_threshold_duration_s, ...
            burst_intervals, ...
            burst_auc, ...
            burst_auc_snr_s, ...
            burst_peak_snr, ...
            burst_peak_prominence_snr, ...
            burst_significant_size ...
        ] = ...
            compute_burst_metrics_from_raster( ...
                Raster, ...
                DF, ...
                thresholds, ...
                noise_est, ...
                sampling_rate, ...
                bad_frame_mask, ...
                burst_options);


        metrics.burst_rate_by_plane{p} = ...
            burst_rate;


        metrics.burst_fraction_by_plane{p} = ...
            burst_fraction;


        metrics.burst_size_by_plane{p} = ...
            burst_size;

        metrics.burst_duration_s_by_plane{p} = ...
            burst_duration_s;

        metrics.burst_above_threshold_duration_s_by_plane{p} = ...
            burst_above_threshold_duration_s;

        metrics.burst_intervals_by_plane{p} = burst_intervals;
        metrics.burst_auc_by_plane{p} = burst_auc;
        metrics.burst_auc_snr_s_by_plane{p} = burst_auc_snr_s;
        metrics.burst_peak_snr_by_plane{p} = burst_peak_snr;
        metrics.burst_peak_prominence_snr_by_plane{p} = ...
            burst_peak_prominence_snr;
        metrics.burst_significant_size_by_plane{p} = burst_significant_size;
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
    burst_rate_per_cell_per_min, ...
    burst_fraction_per_cell, ...
    burst_size_all, ...
    burst_duration_s_all, ...
    burst_above_threshold_duration_s_all, ...
    burst_intervals_by_cell, ...
    burst_auc_all, ...
    burst_auc_snr_s_all, ...
    burst_peak_snr_all, ...
    burst_peak_prominence_snr_all, ...
    burst_significant_size_all] = ...
    compute_burst_metrics_from_raster( ...
        Raster, DF, thresholds, noise_est, ...
        sampling_rate, bad_frame_mask, opts)

    burst_rate_per_cell_per_min = [];
    burst_fraction_per_cell = [];
    burst_size_all = [];
    burst_duration_s_all = [];
    burst_above_threshold_duration_s_all = [];
    burst_intervals_by_cell = {};
    burst_auc_all = [];
    burst_auc_snr_s_all = [];
    burst_peak_snr_all = [];
    burst_peak_prominence_snr_all = [];
    burst_significant_size_all = [];

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
    duration_min = nnz(valid_frames)/sampling_rate/60;
    burst_rate_per_cell_per_min = nan(nCells, 1);
    burst_fraction_per_cell = nan(nCells, 1);
    if duration_min <= 0
        return;
    end

    % Seuil et bruit SPECIFIQUES a chaque cellule : ceux du peak tuner.
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
    min_sep_frames = opts.min_peak_separation_s*sampling_rate;

    for c = 1:nCells
        original_x = double(DF(c, :));
        % Corriger la trace pour les BURSTS uniquement. Les frames
        % non interpolables (bords, absence de voisins valides) et les
        % NaN independants du masque de mouvement restent des coupures.
        [x, ~, unfilled_bad] = interpolate_burst_bad_frames( ...
            original_x, bad_frame_mask);
        sigma = noise_est(c);
        threshold = thresholds(c);
        if ~isfinite(sigma) || sigma <= 0 || ~isfinite(threshold)
            % Ne pas substituer un seuil estime au seuil sauvegarde.
            continue;
        end

        cell_valid = ~unfilled_bad & isfinite(x);
        % Les pics originaux presents sur les bad frames ne sont JAMAIS
        % recuperes artificiellement par l'interpolation de fluorescence.
        original_event_valid = valid_frames & isfinite(original_x);
        n_valid_events = nnz(Raster(c, :) & original_event_valid);
        burst_rate_per_cell_per_min(c) = 0;
        if n_valid_events == 0
            burst_fraction_per_cell(c) = NaN;
            continue;
        end

        d = diff([false, cell_valid, false]);
        seg_start = find(d == 1);
        seg_end = find(d == -1)-1;
        accepted = zeros(0, 2);

        for seg = 1:numel(seg_start)
            a = seg_start(seg);
            b = seg_end(seg);
            if b-a+1 < 2
                continue;
            end

            % Positivite + lissage : integrateur d'activite, pas detection
            % de pics. Les bad frames deja interpolees participent a
            % l'enveloppe ; les lacunes restantes restent des coupures.
            activity = max(x(a:b), 0)/sigma;
            envelope = movmean(activity, smooth_frames);

            % Hysteresis : les zones au-dessus du seuil BAS sont des
            % candidats uniquement si elles contiennent un passage au
            % seuil HAUT. Des oscillations autour du haut ne decoupent pas.
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

                % Frontieres au franchissement de l'enveloppe avec le
                % seuil BAS (interpolation lineaire, frames fractionnaires).
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

            % Fusion dans le MEME segment continu apres interpolation,
            % AVANT validation (y compris a travers une courte lacune
            % de mouvement dont la trace a ete interpolee).
            merged = merge_burst_intervals( ...
                candidates, sampling_rate, opts.merge_gap_s);

            for k = 1:size(merged, 1)
                left = merged(k, 1);
                right = merged(k, 2);
                episode_duration = (right-left)/sampling_rate;
                if episode_duration < opts.min_burst_duration_s
                    continue;
                end

                % Les pics proviennent EXCLUSIVEMENT du raster sauvegarde.
                % Ils ne definissent plus les bornes des episodes.
                peaks = find(Raster(c, a:b)) + a-1;
                peaks = peaks(peaks >= left & peaks <= right & ...
                    original_event_valid(peaks));
                [peaks, prominence_snr] = qualifying_burst_peaks( ...
                    x, peaks, left, right, sigma, threshold, ...
                    min_sep_frames, opts);
                % Criteres cumulatifs : un pic majeur accompagne de petites
                % oscillations NE SUFFIT PLUS. Les pics doivent etre
                % independants, d'amplitude suffisante et repartis dans
                % le temps. AUC et duree au-dessus du seuil sont des
                % metriques, elles ne peuvent pas compenser un manque de pics.
                if numel(peaks) < opts.min_peaks
                    continue;
                end

                peak_snr = x(peaks)/sigma;
                strong_peaks = ...
                    peak_snr >= opts.min_peak_snr & ...
                    prominence_snr >= opts.min_strong_peak_prominence_snr;
                if nnz(peak_snr >= opts.min_secondary_peak_snr) < ...
                        opts.min_peaks || ...
                        nnz(strong_peaks) < ...
                        opts.min_strong_peaks
                    continue;
                end

                peak_span_s = (peaks(end)-peaks(1))/sampling_rate;
                if peak_span_s < opts.min_peak_span_s
                    continue;
                end

                accepted(end+1, :) = [left right]; %#ok<AGROW>
            end
        end

        % Calcul des metriques et trace rouge : meme liste d'intervalles.
        accepted = sortrows(accepted, [1 2]);
        burst_intervals_by_cell{c} = accepted;
        burst_rate_per_cell_per_min(c) = size(accepted, 1)/duration_min;
        n_burst_events = 0;
        all_events = find(Raster(c, :) & original_event_valid);

        for i = 1:size(accepted, 1)
            left = accepted(i, 1);
            right = accepted(i, 2);
            peaks = all_events(all_events >= left & all_events <= right);
            n_burst_events = n_burst_events + numel(peaks);
            burst_size_all(end+1, 1) = numel(peaks); %#ok<AGROW>

            [good_peaks, good_prominence_snr] = qualifying_burst_peaks( ...
                x, peaks, left, right, sigma, threshold, ...
                min_sep_frames, opts);
            burst_significant_size_all(end+1, 1) = ...
                nnz(x(good_peaks)/sigma >= opts.min_peak_snr & ...
                good_prominence_snr >= ...
                opts.min_strong_peak_prominence_snr); %#ok<AGROW>
            burst_peak_snr_all(end+1, 1) = ...
                max(x(good_peaks))/sigma; %#ok<AGROW>
            burst_peak_prominence_snr_all(end+1, 1) = ...
                max(good_prominence_snr); %#ok<AGROW>

            [above_s, auc] = integrate_above_threshold( ...
                x, threshold, left, right, ...
                sampling_rate, unfilled_bad);
            burst_duration_s_all(end+1, 1) = ...
                (right-left)/sampling_rate; %#ok<AGROW>
            burst_above_threshold_duration_s_all(end+1, 1) = ...
                above_s; %#ok<AGROW>
            burst_auc_all(end+1, 1) = auc; %#ok<AGROW>
            burst_auc_snr_s_all(end+1, 1) = auc/sigma; %#ok<AGROW>
        end

        burst_fraction_per_cell(c) = n_burst_events/n_valid_events;
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

% Garde exclusivement les pics du raster (donc PAS de nouveaux pics sur
% les bad frames interpolees). Un pic doit passer DEUX criteres distincts :
% hauteur / bruit ET prominence locale / bruit. Les bornes du candidat
% limitent la recherche des creux : une autre episode ne peut pas influer.
function [kept, kept_prominence_snr] = qualifying_burst_peaks( ...
    x, peaks, left, right, sigma, threshold, min_separation_frames, opts)

    kept = zeros(1, 0);
    kept_prominence_snr = zeros(1, 0);
    if isempty(peaks)
        return;
    end

    peaks = unique(peaks(:).');
    peaks = peaks(x(peaks) > threshold & ...
        x(peaks)/sigma >= opts.min_support_peak_snr);
    if isempty(peaks)
        return;
    end

    prominence_snr = peak_prominences_from_trace( ...
        x, peaks, left, right)/sigma;
    good = prominence_snr >= opts.min_support_peak_prominence_snr;
    peaks = peaks(good);
    prominence_snr = prominence_snr(good);

    % Deux pics trop proches ou sans creux suffisant ne comptent qu'une
    % fois. Conserver celui qui est le plus proeminent, puis le plus haut.
    for i = 1:numel(peaks)
        kept(end+1) = peaks(i); %#ok<AGROW>
        kept_prominence_snr(end+1) = prominence_snr(i); %#ok<AGROW>
        while numel(kept) >= 2
            first = kept(end-1);
            last = kept(end);
            min_peak = min(x([first, last]));
            valley = min(x(first:last));
            independent = ...
                (last-first >= min_separation_frames) && ...
                (min_peak-valley >= ...
                    opts.min_valley_fraction*(min_peak-threshold));
            if independent
                break;
            end
            earlier_prominence = kept_prominence_snr(end-1);
            later_prominence = kept_prominence_snr(end);
            if later_prominence > earlier_prominence || ...
                    (later_prominence == earlier_prominence && ...
                     x(last) > x(first))
                kept(end-1) = last;
                kept_prominence_snr(end-1) = later_prominence;
            end
            kept(end) = [];
            kept_prominence_snr(end) = [];
        end
    end
end

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
    defaults = struct( ...
        'envelope_window_s', 0.6, ...
        'onset_snr', 3, ...
        'offset_snr', 1.5, ...
        'merge_gap_s', 0.3, ...
        'min_burst_duration_s', 3.0, ...
        'min_peak_snr', 6, ...
        'min_peaks', 5, ...
        'min_strong_peaks', 3, ...
        'min_support_peak_snr', 4.5, ...
        'min_secondary_peak_snr', 4.5, ...
        'min_support_peak_prominence_snr', 1.5, ...
        'min_strong_peak_prominence_snr', 2.5, ...
        'min_peak_separation_s', 0.30, ...
        'min_peak_span_s', 2.0, ...
        'min_valley_fraction', 0.25);
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
    validateattributes(opts.min_strong_peaks, {'numeric'}, ...
        {'integer', '>=', 1}, mfilename, 'burst_options.min_strong_peaks');
    if opts.min_strong_peaks > opts.min_peaks
        error('min_strong_peaks ne peut pas depasser min_peaks.');
    end
    if opts.onset_snr <= opts.offset_snr
        error('burst_options.onset_snr doit depasser offset_snr.');
    end
    if opts.min_support_peak_snr > opts.min_secondary_peak_snr || ...
            opts.min_secondary_peak_snr > opts.min_peak_snr
        error('Verifier l ordre des trois seuils SNR de pics.');
    end
    if opts.min_support_peak_prominence_snr > ...
            opts.min_strong_peak_prominence_snr
        error('Le seuil de prominence des pics forts doit etre >= au seuil support.');
    end
    if opts.min_valley_fraction > 1
        error('Les fractions de burst_options doivent etre <= 1.');
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
            views(v).bad = get_bad_frame_mask(data, m, size(DF, 2));
            views(v).bursts = bursts;
        end
    end

    if isempty(views)
        return;
    end

    fig = figure( ...
        'Name', sprintf('Burst viewer | recording %d', m), ...
        'NumberTitle', 'off', 'Color', 'w', ...
        'Units', 'normalized', 'Position', [0.12 0.15 0.76 0.66], ...
        'MenuBar', 'none', 'ToolBar', 'figure');

    ax = axes('Parent', fig, 'Units', 'normalized', ...
        'Position', [0.075 0.24 0.89 0.67]);

    labels = {views.label};
    planMenu = uicontrol(fig, 'Style', 'popupmenu', ...
        'Units', 'normalized', 'Position', [0.075 0.09 0.39 0.075], ...
        'String', labels, 'Value', 1, 'Callback', @change_plan);

    cellSlider = uicontrol(fig, 'Style', 'slider', ...
        'Units', 'normalized', 'Position', [0.51 0.11 0.37 0.045], ...
        'Min', 1, 'Max', 2, 'Value', 1, 'Callback', @change_cell);

    cellLabel = uicontrol(fig, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.89 0.095 0.08 0.055], ...
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
        if ~isgraphics(fig) || ~isgraphics(ax)
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

        cla(ax);
        hold(ax, 'on');
        plot(ax, t, visibleX, 'k-', 'LineWidth', 0.8);
        % Traces interpolees visibles en pointilles gris, non mesurees.
        if any(interpolated)
            runs = diff([false, interpolated, false]);
            starts = find(runs == 1);
            ends = find(runs == -1)-1;
            for r = 1:numel(starts)
                idx = max(1, starts(r)-1):min(numel(x), ends(r)+1);
                plot(ax, t(idx), visibleX(idx), '--', ...
                    'Color', [0.55 0.55 0.55], 'LineWidth', 1.2);
            end
        end

        % Même fenêtre que les métriques (aucun recalcul de bursts).
        intervals = view.bursts{c};
        if ~isempty(intervals)
            for iburst = 1:size(intervals, 1)
                draw_red_interval(ax, x, bad, ...
                    intervals(iburst, :), sampling_rate);
            end
        end

        % Conserver uniquement les pics originaux hors bad frames.
        % Cercles pleins : pics FORTS valides en amplitude ET prominence,
        % dans un burst retenu. Cercles vides : autres pics sauvegardes.
        pk = find(view.Raster(c, :) & ~view.bad & isfinite(original_x));
        if ~isempty(pk)
            sigma = view.noise_est(c);
            significant = false(size(pk));
            threshold = view.thresholds(c);
            if isfinite(sigma) && sigma > 0 && isfinite(threshold)
                for iburst = 1:size(intervals, 1)
                    left = intervals(iburst, 1);
                    right = intervals(iburst, 2);
                    inside = pk >= left & pk <= right;
                    [good, prom_snr] = qualifying_burst_peaks( ...
                        x, pk(inside), left, right, sigma, threshold, ...
                        metrics.burst_options.min_peak_separation_s*sampling_rate, ...
                        metrics.burst_options);
                    strong = x(good)/sigma >= ...
                        metrics.burst_options.min_peak_snr & ...
                        prom_snr >= ...
                        metrics.burst_options.min_strong_peak_prominence_snr;
                    significant(ismember(pk, good(strong))) = true;
                end
            end
            plot(ax, t(pk(~significant)), x(pk(~significant)), ...
                'o', 'LineStyle', 'none', ...
                'Color', [0.53 0.68 0.86], 'MarkerSize', 4, ...
                'LineWidth', 0.8);
            plot(ax, t(pk(significant)), x(pk(significant)), ...
                'o', 'LineStyle', 'none', ...
                'Color', [0.08 0.30 0.85], ...
                'MarkerFaceColor', [0.08 0.30 0.85], ...
                'MarkerSize', 5, 'LineWidth', 1);
        end

        thr = view.thresholds(c);
        if isfinite(thr)
            yline(ax, thr, '--', 'Color', [0.15 0.52 0.80], ...
                'LineWidth', 1);
        end

        if ~isfinite(view.noise_est(c)) || view.noise_est(c) <= 0 || ...
                ~isfinite(view.thresholds(c))
            title_text = sprintf([ ...
                '%s | Cellule %d | SNR indisponible (noise_est absent)' ...
                ' | bursts non calcules'], view.label, c);
        else
            title_text = { ...
                sprintf(['%s | Cellule %d | %d pics detectes | %d bursts' ...
                    ' | %d bad frames interpolees'], ...
                    view.label, c, numel(pk), size(intervals, 1), nnz(interpolated)), ...
                sprintf(['Enveloppe %.2f s | entree %.1f sigma | sortie %.1f sigma' ...
                    ' | fusion < %.0f ms | duree >= %.1f s'], ...
                    metrics.burst_options.envelope_window_s, ...
                    metrics.burst_options.onset_snr, ...
                    metrics.burst_options.offset_snr, ...
                    1000*metrics.burst_options.merge_gap_s, ...
                    metrics.burst_options.min_burst_duration_s), ...
                sprintf(['Validation : >= %d pics distincts (amp >= %.1f, prom >= %.1f sigma)' ...
                    ' | >= %d pics forts (amp >= %.1f, prom >= %.1f sigma)' ...
                    ' | etalement >= %.1f s'], ...
                    metrics.burst_options.min_peaks, ...
                    metrics.burst_options.min_secondary_peak_snr, ...
                    metrics.burst_options.min_support_peak_prominence_snr, ...
                    metrics.burst_options.min_strong_peaks, ...
                    metrics.burst_options.min_peak_snr, ...
                    metrics.burst_options.min_strong_peak_prominence_snr, ...
                    metrics.burst_options.min_peak_span_s) ...
            };
        end
        title(ax, title_text, 'Interpreter', 'none');
        xlabel(ax, 'Temps (s)');
        ylabel(ax, '\DeltaF/F');
        xlim(ax, [0 max(1/sampling_rate, t(end))]);
        box(ax, 'off');
        hold(ax, 'off');
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
            'burst_rate_by_plane', {{}}, ...
            'burst_fraction_by_plane', {{}}, ...
            'burst_size_by_plane', {{}}, ...
            'burst_duration_s_by_plane', {{}}, ...
            'burst_above_threshold_duration_s_by_plane', {{}}, ...
            'burst_auc_by_plane', {{}}, ...
            'burst_auc_snr_s_by_plane', {{}}, ...
            'burst_peak_snr_by_plane', {{}}, ...
            'burst_peak_prominence_snr_by_plane', {{}}, ...
            'burst_significant_size_by_plane', {{}}, ...
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
% Bad frames
%==================================================================%
function bad_frame_mask = get_bad_frame_mask( ...
        data, ...
        m, ...
        nFrames)

    bad_frame_mask = ...
        false(1, nFrames);


    if nargin < 3 || ...
            isempty(nFrames) || ...
            nFrames <= 0

        return;
    end


    if ~isstruct(data) || ...
            ~isfield(data, 'motion') || ...
            ~isstruct(data.motion) || ...
            ~isfield(data.motion, 'bad_frames_group') || ...
            isempty(data.motion.bad_frames_group) || ...
            numel(data.motion.bad_frames_group) < m

        return;
    end


    bad_frames = ...
        data.motion.bad_frames_group{m};


    if isempty(bad_frames)
        return;
    end


    bad_frame_mask = ...
        convert_bad_frames_to_mask( ...
            bad_frames, ...
            nFrames);
end


function bad_frame_mask = convert_bad_frames_to_mask( ...
        bad_frames, ...
        nFrames)

    bad_frame_mask = ...
        false(1, nFrames);


    if isempty(bad_frames)
        return;
    end


    if iscell(bad_frames)

        for i = 1:numel(bad_frames)

            current_mask = ...
                convert_bad_frames_to_mask( ...
                    bad_frames{i}, ...
                    nFrames);


            bad_frame_mask = ...
                bad_frame_mask | ...
                current_mask;
        end

        return;
    end


    if islogical(bad_frames)

        bad_frames = ...
            bad_frames(:).';


        nCopy = ...
            min( ...
                numel(bad_frames), ...
                nFrames);


        bad_frame_mask(1:nCopy) = ...
            bad_frames(1:nCopy);

        return;
    end


    if ~isnumeric(bad_frames)
        return;
    end


    bad_frames = ...
        double( ...
            bad_frames(:).');


    bad_frames = ...
        bad_frames( ...
            isfinite(bad_frames));


    if isempty(bad_frames)
        return;
    end


    is_binary_mask = ...
        numel(bad_frames) == nFrames && ...
        all( ...
            bad_frames == 0 | ...
            bad_frames == 1);


    if is_binary_mask

        bad_frame_mask = ...
            logical(bad_frames);

        return;
    end


    bad_indices = ...
        unique( ...
            round(bad_frames));


    bad_indices = ...
        bad_indices( ...
            bad_indices >= 1 & ...
            bad_indices <= nFrames);


    bad_frame_mask(bad_indices) = ...
        true;
end