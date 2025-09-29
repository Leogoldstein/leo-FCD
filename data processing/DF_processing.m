function [DF_sg, baseline_values, noise_est, SNR] = DF_processing(F, varargin)
    % Preprocess fluorescence traces and compute ΔF/F, noise and SNR.
    %
    % Inputs:
    % - F: raw fluorescence (cells x time).
    %
    % Optional Name-Value pairs:
    % - 'WindowSize'  : baseline window size (default = 2000)
    % - 'Percentile'  : percentile for baseline (default = 5)
    % - 'NoiseWindow' : rolling window size for noise estimation (default = 20)
    % - 'NoiseMethod' : 'mean' | 'median' | 'max' (default = 'mean')
    %
    % Outputs:
    % - DF              : ΔF/F matrix
    % - baseline_values : baseline per cell
    % - noise_est       : noise estimate (cells x time)
    % - SNR             : signal-to-noise ratio (cells x time)

    % --- Parameters ---
    p = inputParser;
    addParameter(p, 'WindowSize', 2000);
    addParameter(p, 'Percentile', 5);
    addParameter(p, 'NoiseWindow', 10);
    addParameter(p, 'NoiseMethod', 'mean');
    parse(p, varargin{:});

    window_size   = p.Results.WindowSize;
    percentile    = p.Results.Percentile;
    noise_window  = p.Results.NoiseWindow;
    noise_method  = p.Results.NoiseMethod;

    [NCell, Nz] = size(F);

    % --- Step 1: Baseline estimation & ΔF/F ---
    DF = nan(NCell, Nz);
    baseline_values = nan(NCell, 1);
    for n = 1:NCell
        trace = F(n,:);
        F0 = nan(Nz,1);

        % percentile-based baseline block by block
        num_blocks = ceil(Nz / window_size);
        for i = 1:num_blocks
            start_idx = (i-1)*window_size + 1;
            end_idx   = min(i*window_size, Nz);
            F0(start_idx:end_idx) = prctile(trace(start_idx:end_idx), percentile);
        end

        % smooth baseline
        F0 = movmedian(F0, window_size, 'omitnan');
        F0 = smoothdata(F0, 1, 'gaussian', window_size/2);

        baseline_values(n) = mean(F0, 'omitnan');
        DF(n,:) = (trace - F0') ./ F0';
    end

    % --- Step 2: Noise estimation ---
    noise_est = nan(NCell, Nz);
    DF_sg     = nan(NCell, Nz); % smoothed ΔF/F (for SNR)
    for n = 1:NCell
        sig    = DF(n,:);
        sig_sg = sgolayfilt(sig, 3, 5); % SavGol smoothing on ΔF/F
        DF_sg(n,:) = sig_sg;

        raw_noise = abs(sig - sig_sg);

        % rolling window refinement
        switch lower(noise_method)
            case 'mean'
                noise_est(n,:) = movmean(raw_noise, noise_window);
            case 'median'
                noise_est(n,:) = movmedian(raw_noise, noise_window);
            case 'max'
                noise_est(n,:) = movmax(raw_noise, noise_window);
            otherwise
                error('NoiseMethod must be mean, median, or max.');
        end
    end

    % --- Step 3: SNR ---
    SNR = DF_sg ./ noise_est; % element-wise division
end
