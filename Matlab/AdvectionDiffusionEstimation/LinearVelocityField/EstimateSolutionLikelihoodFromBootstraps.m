function jointLikelihood = EstimateSolutionLikelihoodFromBootstraps(bootstraps,parameters,dt)
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here

% Zdravko Botev (2020). kernel density estimation (https://www.mathworks.com/matlabcentral/fileexchange/17204-kernel-density-estimation), MATLAB Central File Exchange. Retrieved November 25, 2020.

shouldEstimateU0V0 = 0;
shouldEstimateU1V1 = 0;
shouldEstimateStrain = 0;
shouldEstimateVorticity = 0;
shouldEstimateDivergence = 0;

nT = 0;
for i=1:length(parameters)
    if  parameters(i) == ModelParameter.u0v0
        shouldEstimateU0V0 = 1;
        if nT > 0 && size(bootstraps.u0,1) ~= nT
            error('inconsistent time series sizes');
        else
            nT = size(bootstraps.u0,1);
            totalPermutations = size(bootstraps.u0,2);
        end
    elseif  parameters(i) == ModelParameter.u1v1
        shouldEstimateU1V1 = 1;
        if nT > 0 && size(bootstraps.u1,1) ~= nT
            error('inconsistent time series sizes');
        else
            nT = size(bootstraps.u1,1);
            totalPermutations = size(bootstraps.u1,2);
        end
    elseif  parameters(i) == ModelParameter.strain
        shouldEstimateStrain = 1;
        if nT > 0 && size(bootstraps.sigma_n,1) ~= nT
            error('inconsistent time series sizes');
        else
            nT = size(bootstraps.sigma_n,1);
            totalPermutations = size(bootstraps.sigma_n,2);
        end
    elseif  parameters(i) == ModelParameter.vorticity
        shouldEstimateVorticity = 1;
        if nT > 0 && size(bootstraps.zeta,1) ~= nT
            error('inconsistent time series sizes');
        else
            nT = size(bootstraps.zeta,1);
            totalPermutations = size(bootstraps.zeta,2);
        end
    elseif  parameters(i) == ModelParameter.divergence
        shouldEstimateDivergence = 1;
        if nT > 0 && size(bootstraps.delta,1) ~= nT
            error('inconsistent time series sizes');
        else
            nT = size(bootstraps.delta,1);
            totalPermutations = size(bootstraps.delta,2);
        end
    end
end

m = bootstraps;
jointLikelihood = zeros(length(1:dt:nT),totalPermutations);
for iTime=1:dt:nT
    if shouldEstimateU0V0 == 1    
        [~,density,X,Y]=kde2d(cat(2,m.u0(iTime,:).',m.v0(iTime,:).'));
        jointLikelihood(i,:) = jointLikelihood(i,:) + log10(interp2(X,Y,density,m.u0(iTime,:),m.v0(iTime,:)));
    end
    if shouldEstimateU1V1 == 1
        [~,density,X,Y]=kde2d(cat(2,m.u1(iTime,:).',m.v1(iTime,:).'));
        jointLikelihood(i,:) = jointLikelihood(i,:) + log10(interp2(X,Y,density,m.u1(iTime,:),m.v1(iTime,:)));
    end
    if shouldEstimateStrain == 1
        [~,density,X,Y]=kde2d(cat(2,m.sigma_n(iTime,:).',m.sigma_s(iTime,:).'));
        jointLikelihood(i,:) = jointLikelihood(i,:) + log10(interp2(X,Y,density,m.sigma_n(iTime,:),m.sigma_s(iTime,:)));
    end
    if shouldEstimateVorticity == 1
        [~,density,X]=kde(m.zeta(iTime,:).');
        jointLikelihood(i,:) = jointLikelihood(i,:) + log10(interp1(X,density,m.zeta(iTime,:)));
    end
    if shouldEstimateDivergence == 1
        [~,density,X]=kde(m.delta(iTime,:).');
        jointLikelihood(i,:) = jointLikelihood(i,:) + log10(interp1(X,density,m.delta(iTime,:)));
    end
end
jointLikelihood = sum(jointLikelihood,1);
end

