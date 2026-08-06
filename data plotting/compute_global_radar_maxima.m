function global_maxima = compute_global_radar_maxima( ...
        grouped_by_type, ...
        type_names)
%COMPUTE_GLOBAL_RADAR_MAXIMA
%
% Maximum commun entre tous les types et tous les âges pour :
%
%   1) GCaMP activity
%      -> FrequencyPerCell_gcamp
%
%   2) Global network correlation
%      -> pairwise_corr_gcamp_gcamp
%
%   3) Network event frequency
%      -> SCEsFrequency
%
%   4) Network recruitment
%      -> SCEsCellParticipation_percent
%
%   5) Burstiness
%      -> BurstFraction_gcamp
%
% Chaque valeur représentée dans le radar est la médiane des
% observations regroupées pour un âge.
%
% La normalisation commune utilise ensuite le maximum de ces
% médianes parmi tous les types et tous les âges.


    metric_fields = { ...
        'FrequencyPerCell_gcamp', ...
        'pairwise_corr_gcamp_gcamp', ...
        'SCEsFrequency', ...
        'SCEsCellParticipation_percent', ...
        'BurstFraction_gcamp' ...
    };


    nMetrics = ...
        numel(metric_fields);


    global_maxima = ...
        nan(1, nMetrics);


    %==============================================================%
    % Métriques
    %==============================================================%
    for m = 1:nMetrics

        all_medians = [];


        %==========================================================%
        % Types
        %==========================================================%
        for t = 1:numel(type_names)

            current_type = ...
                type_names{t};


            if ~isfield( ...
                    grouped_by_type, ...
                    current_type)

                continue;
            end


            G = ...
                grouped_by_type.(current_type);


            if ~isfield( ...
                    G, ...
                    metric_fields{m})

                continue;
            end


            vals_by_age = ...
                G.(metric_fields{m});


            %======================================================%
            % Ages
            %======================================================%
            for a = 1:numel(vals_by_age)

                vals = ...
                    clean_numeric_local( ...
                        vals_by_age{a});


                if isempty(vals)
                    continue;
                end


                med = ...
                    median( ...
                        vals, ...
                        'omitnan');


                if isfinite(med)

                    all_medians(end + 1, 1) = ...
                        med; %#ok<AGROW>
                end
            end
        end


        %==========================================================%
        % Maximum global
        %==========================================================%
        if ~isempty(all_medians)

            global_maxima(m) = ...
                max( ...
                    all_medians, ...
                    [], ...
                    'omitnan');
        end
    end
end


function x = clean_numeric_local(x)

    if isempty(x) || ...
            ~(isnumeric(x) || islogical(x))

        x = [];
        return;
    end


    x = ...
        double(x(:));


    x = ...
        x( ...
            isfinite(x));
end