function [parameters,error] = EstimateLinearVelocityFieldParametersCOMWeighted( x, y, t, parametersToEstimate)

shouldEstimateU0V0 = 0;
shouldEstimateU1V1 = 0;
shouldEstimateStrain = 0;
shouldEstimateVorticity = 0;
shouldEstimateDivergence = 0;
nParameters = 0;

if isequal(class(parametersToEstimate),'ModelParameter')
    for i=1:length(parametersToEstimate)
       if  parametersToEstimate(i) == ModelParameter.u0v0
           shouldEstimateU0V0 = 1; nParameters = nParameters + 2;
       elseif  parametersToEstimate(i) == ModelParameter.u1v1
           shouldEstimateU1V1 = 1; nParameters = nParameters + 2;
       elseif  parametersToEstimate(i) == ModelParameter.strain
           shouldEstimateStrain = 1; nParameters = nParameters + 2;
       elseif  parametersToEstimate(i) == ModelParameter.vorticity
           shouldEstimateVorticity = 1; nParameters = nParameters + 1;
       elseif  parametersToEstimate(i) == ModelParameter.divergence
           shouldEstimateDivergence = 1; nParameters = nParameters + 1;
       end
    end
elseif isequal(class(parametersToEstimate),'char')
    if strcmp(parametersToEstimate,'strain-diffusive')
        shouldEstimateStrain = 1;
    elseif strcmp(parametersToEstimate,'vorticity-strain-diffusive')
        shouldEstimateStrain = 1;
        shouldEstimateVorticity = 1;
    end
end

u0 = 0;
v0 = 0;
u1 = 0;
v1 = 0;
sigma_n = 0;
sigma_s = 0;
zeta = 0;
delta = 0;

nDrifters = size(x,2);

% Compute velocities with 2nd order accuracy
D = FiniteDifferenceMatrix(1,t,1,1,2);

% Center-of-mass, and velocity of center-of-mass
mx = mean(x,2);
my = mean(y,2);

dmxdt = D*mx;
dmydt = D*my;

% Positions and velocities relative to the center-of-mass
q = x-mx;
r = y-my;

dqdt = D*q;
drdt = D*r;

% Now put all the data together
onesB = zeros(length(t)*nDrifters,1);
zerosB = zeros(length(t)*nDrifters,1);
tB = zeros(length(t)*nDrifters,1);
qB = zeros(length(t)*nDrifters,1);
rB = zeros(length(t)*nDrifters,1);
u = zeros(length(t)*nDrifters,1);
v = zeros(length(t)*nDrifters,1);
for iDrifter=1:nDrifters
    indices = (1:length(t)) + (iDrifter-1)*length(t);
    onesB(indices,:) = ones(size(q(:,iDrifter)));
    zerosB(indices,:) = zeros(size(q(:,iDrifter)));
    tB(indices,:) = t;
    qB(indices,:) = q(:,iDrifter);
    rB(indices,:) = r(:,iDrifter);
    u(indices) = dqdt(:,iDrifter);
    v(indices) = drdt(:,iDrifter);
end

% needed for the COM trajectory.
onesM = ones(length(t),1);
zerosM = zeros(length(t),1);

% Ru/Rv stores the data for the drifters *in* the COM frame
% Ru_cm/Rv_cm stores the data *of* the COM frame.
Ru = []; Rv = []; Ru_cm = []; Rv_cm = [];
if shouldEstimateU0V0 == 1
    Ru = cat(2,Ru,zerosB,zerosB);
    Rv = cat(2,Rv,zerosB,zerosB);
    Ru_cm = cat(2,Ru_cm,onesM,zerosM);
    Rv_cm = cat(2,Rv_cm,zerosM,onesM);
end
if shouldEstimateU1V1 == 1
    Ru = cat(2,Ru,zerosB,zerosB);
    Rv = cat(2,Rv,zerosB,zerosB);
    Ru_cm = cat(2,Ru_cm,t,zerosM);
    Rv_cm = cat(2,Rv_cm,zerosM,t);
end
if shouldEstimateStrain == 1
    Ru = cat(2,Ru,qB/2,rB/2);
    Rv = cat(2,Rv,-rB/2,qB/2);
    Ru_cm = cat(2,Ru_cm,mx/2,my/2);
    Rv_cm = cat(2,Rv_cm,-my/2,mx/2);
end
if shouldEstimateVorticity == 1
    Ru = cat(2,Ru,-rB/2);
    Rv = cat(2,Rv,qB/2);
    Ru_cm = cat(2,Ru_cm,-my/2);
    Rv_cm = cat(2,Rv_cm,mx/2);
end
if shouldEstimateDivergence == 1
    Ru = cat(2,Ru,qB/2);
    Rv = cat(2,Rv,rB/2);
    Ru_cm = cat(2,Ru_cm,mx/2);
    Rv_cm = cat(2,Rv_cm,my/2);
end

U = cat(1,u,v);
R = cat(1,Ru,Rv);

U = cat(1,U,dmxdt,dmydt);
R = cat(1,R,Ru_cm,Rv_cm);

m = (R.' * R) \ (R.' * U);

p = 0;
if shouldEstimateU0V0 == 1
    p = p + 1; u0 = m(p);
    p = p + 1; v0 = m(p);
end
if shouldEstimateU1V1 == 1
    p = p + 1; u1 = m(p);
    p = p + 1; v1 = m(p);
end
if shouldEstimateStrain == 1
    p = p + 1; sigma_n = m(p);
    p = p + 1; sigma_s = m(p);
end
if shouldEstimateVorticity == 1
    p = p + 1; zeta = m(p);
end
if shouldEstimateDivergence == 1
    p = p + 1; delta = m(p);
end

% 
% uv_model=R*m;
% u = uv_model(1:(length(uv_model)/2));
% v = uv_model((length(uv_model)/2+1):end);
% u = reshape(u,[length(t) nDrifters]);
% v = reshape(v,[length(t) nDrifters]);
% 
% u_res = dxdt - u;
% v_res = dydt - v;
% 
% u_bg = mean(u_res,2);
% v_bg = mean(v_res,2);
% 
% u_sm = u_res - u_bg;
% v_sm = v_res - v_bg;
% 
% x_sm = cumtrapz(t,u_sm);
% y_sm = cumtrapz(t,v_sm);



parameters.u0 = u0;
parameters.v0 = v0;
parameters.ut = u1;
parameters.vt = v1;
parameters.sigma_n = sigma_n;
parameters.sigma_s = sigma_s;
parameters.zeta = zeta;
parameters.delta = delta;
parameters.sigma = sqrt(sigma_n^2 + sigma_s^2);
parameters.theta = atan2(sigma_s,sigma_n)/2;
parameters.kappa = 0; %mean(x_sm(end,:).^2 + y_sm(end,:).^2)/(4*(t(end)-t(1)));
error = 0;

end

