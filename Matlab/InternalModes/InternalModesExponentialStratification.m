classdef InternalModesExponentialStratification < InternalModesBase
    properties (Access = public)
        N0
        b
        rho
        N2
        rho_z
        rho_zz
        
        nInitialSearchModes = 128
        
        % analytical solutions
        GSolution
        FSolution
        
        shouldApproximate
        GSolutionApprox
        FSolutionApprox
    end
    
    methods
        function self = InternalModesExponentialStratification(rho, z_in, z_out, latitude, varargin) 
            % rho should be a two component vector with the buoyancy at the
            % surface and the e-fold scale, e.g., [5.2e-3 1300].
            if isa(rho,'numeric') == true && (length(rho) == 2 || length(rho) == 3)
                N0 = rho(1);
                b = rho(2);
                if length(rho) == 3
                    rho0 = rho(3);
                else
                    rho0 = 1025;
                end
                g = 9.81;
                rhoFunction = @(z) rho0*(1 + b*N0*N0/(2*g)*(1 - exp(2*z/b)));
                N2Function = @(z) N0*N0*exp(2*z/b);
            else
                error('Invalid initialization: rho must be a two-component vector with the bouyancy at the surface and the e-fold scale, e.g., [5.2e-3 1300], or a three-component vector that includes the density at the surface as the final argument.\n');
            end
            
            self@InternalModesBase(rhoFunction,z_in,z_out,latitude, varargin{:});
            self.N0 = N0;
            self.b = b;
            
            self.rho = rhoFunction(self.z);
            self.N2 = N2Function(self.z);
            self.rho_z = -(self.rho0*self.N0*self.N0/self.g)*exp(2*self.z/self.b);
            self.rho_zz = -(2*self.rho0*self.N0*self.N0/self.g/self.b)*exp(2*self.z/self.b);
            
            D = self.Lz;
            alpha = @(omega,c) besselj(omega*b./c,N0*b*exp(-D/b)./c) ./ bessely(omega*b./c,N0*b*exp(-D/b)./c );
                        
            self.GSolution = @(z,omega,c) besselj(b*(omega/c),(b*N0/c)*exp(z/self.b) ) - alpha(omega,c) .* bessely(b*(omega/c),(b*N0/c)*exp(z/self.b));
            self.FSolution = @(z,omega,c) (N0*exp(z/b)*c/2/g) .* ( (besselj(b*(omega/c)-1,(b*N0/c)*exp(z/b)) - besselj(b*(omega/c) + 1,(b*N0/c)*exp(z/b))) -  alpha(omega,c) .* (bessely(b*(omega/c)-1,(b*N0/c)*exp(z/b))-bessely(b*(omega/c)+1,(b*N0/c)*exp(z/b))) );
            
            self.shouldApproximate = @(omega,c) abs( alpha(omega,c) ) < 1e-15;
            self.GSolutionApprox = @(z,omega,c) besselj(b*(omega/c),(b*N0/c)*exp(z/self.b) );
            self.FSolutionApprox = @(z,omega,c) (N0*exp(z/b)*c/2/g) .* ( (besselj(b*(omega/c)-1,(b*N0/c)*exp(z/b)) - besselj(b*(omega/c) + 1,(b*N0/c)*exp(z/b))) );
    
            fprintf('Using the analytical form for exponential stratification N0=%.7g and b=%d\n',self.N0,self.b);
        end
                
        function [F,G,h,omega] = ModesAtWavenumber(self, k )            
            epsilon = self.f0/self.N0;
            lambda = k*self.b;
            
            % These are our "low frequency" (lf) and "high frequency" (hf)
            % estimates of the eigenvalues, taken from Desaubies 1975. We
            % use these as bounds in our root finding algorithm.
            x_lf = @(j,lambda) (j-1/4)*pi + lambda*pi/2;
            x_hf = @(j,lambda) lambda.*(1+0.5*(3*pi*(4*j-1)./(lambda*8*sqrt(2))).^(2/3));
            
            if lambda < 2*(1-1/4)*1e-1
                x_lowerbound = @(lambda) x_lf(1,lambda);
            else
                x_lowerbound = @(lambda) x_hf(1,lambda);
            end
            if lambda < (self.nInitialSearchModes-1/4)
                x_upperbound = @(lambda) x_lf(self.nInitialSearchModes*1.1,lambda);
            else
                x_upperbound = @(lambda) x_hf(self.nInitialSearchModes*5,lambda);
            end
            
            nu = @(x) sqrt( epsilon^2 * x.^2 + lambda^2 );
            s = @(x) x;
            x_nu = lambda/sqrt(5*5*exp(-2*self.Lz/self.b) - epsilon*epsilon);
            
            bounds = [x_lowerbound(lambda) x_upperbound(lambda)];
            r = FindRootsInRange(self, nu, s, bounds, x_nu);
            
            while length(r) < self.nModes
                % the roots get closer together
                dr = r(end)-r(end-1);
                bounds = [bounds(2) bounds(2)+dr*self.nInitialModes];
                more_roots = FindRootsInRange(self, nu, s, bounds, x_nu);
                r = [r; more_roots];
            end
            
            h = reshape((self.b*self.N0./r).^2/self.g,1,[]);
            h = h(1:self.nModes);
            
            if self.upperBoundary == UpperBoundary.freeSurface
                h0 = self.BarotropicEquivalentDepthAtWavenumber(k);
                h = cat(2,h0,h(1:self.nModes-1));
            end
            
            omega = self.omegaFromK(h,k);
            
            [F,G] = NormalizedModesForOmegaAndC(self,omega,sqrt(self.g*h));
        end
        
        function [F,G,h,k] = ModesAtFrequency(self, omega )            
            % This is the function that we use to find the eigenvalues,
            % by finding its roots.
            if omega > self.N0*exp(-self.Lz/self.b)
                eta = (sqrt(self.N0^2 - omega^2) - omega*acos(omega/self.N0))/pi;
                x_nu = Inf;
                bounds = [0.5 self.nModes+1]; % the WKB solution should range from [3/4 nModes-1/4]
            else
                eta = (sqrt(self.N0^2 - omega^2) - sqrt(self.N0^2*exp(-2*self.Lz/self.b) - omega^2) - omega*acos(omega/self.N0) + omega*acos(omega/self.N0*exp(self.Lz/self.b)))/pi;
                x_nu = 0;
                bounds = [0.5 self.nModes+1]; % the WKB solution should range from [1 nModes]
            end
            
            if omega < self.N0
                nu = @(x) omega*x/eta;
                s = @(x) self.N0*x/eta;
                r = FindRootsInRange(self, nu, s, bounds, x_nu);
                
                % sqrt(gh)= b*eta/x, so h=(b*eta/x)^2/g
                h = reshape((self.b*eta./r).^2/self.g,1,[]);   
            else
                h = [];
            end
            
            if self.upperBoundary == UpperBoundary.freeSurface
                h0 = self.BarotropicEquivalentDepthAtFrequency(omega);
                h = cat(2,h0,h);
            end
            
            if length(h) > self.nModes
                h = h(1:self.nModes);
            end
            
            [F,G] = NormalizedModesForOmegaAndC(self,omega*ones(size(h)),sqrt(self.g*h));
            
            k = self.kFromOmega(h,omega);
        end
        
        function r = FindRootsInRange(self, nu, s, bounds, x_nu)
            % nu(x) is a function of x [used in the solution J_\nu(s)]
            % s(x) is a function of x [used in the solution J_\nu(s)]
            % bounds is the [xmin xmax] of the region to search for roots
            % x_nu is where the solution transitions from big_nu to
            % small_nu
            x = linspace(bounds(1),bounds(2),self.nInitialSearchModes); % the choice of nInitialModes is somewhat arbitrary here.
            
            if self.upperBoundary == UpperBoundary.rigidLid
                A = @(x) bessely(nu(x),s(x));
                B = @(x) - besselj(nu(x),s(x));
            elseif self.upperBoundary == UpperBoundary.freeSurface
                alpha = self.b*self.N0*self.N0/(2*self.g);
                A = @(x) bessely(nu(x),s(x)) - (alpha./s(x)) .* ( bessely(nu(x)-1,s(x)) - bessely(nu(x)+1,s(x)) );
                B = @(x) - besselj(nu(x),s(x)) + (alpha./s(x)) .* ( besselj(nu(x)-1,s(x)) - besselj(nu(x)+1,s(x)) );
            end
            f_smallnu = @(x) A(x) .* besselj(nu(x),exp(-self.Lz/self.b)*s(x)) + B(x) .* bessely(nu(x),exp(-self.Lz/self.b)*s(x));
            f_bignu = @(x) (A(x) ./ bessely(nu(x),exp(-self.Lz/self.b)*s(x)) ) .* besselj(nu(x),exp(-self.Lz/self.b)*s(x)) + B(x);
            
            % The function omega(x)./(exp(-D/b)*x) will monotonically decay with x.
            % We want to find where it first drops below 5, and use the appropriate
            % form of the equation.
            xcutoffIndex = find( x >= x_nu,1,'first' );
            
            if xcutoffIndex == 1
                % nu is small for all values of x
                f = f_smallnu;
                f_cheb = chebfun(f,bounds,'splitting','on');
                r = roots(f_cheb);
            elseif isempty(xcutoffIndex) == 1
                % nu is large for all values of x
                f = f_bignu;
                f_cheb = chebfun(f,bounds,'splitting','on');
                r = roots(f_cheb);
            else
                % we need to subdivide the interval into small and large.
                f = f_bignu;
                f_cheb = chebfun(f,[bounds(1) x(xcutoffIndex)] ,'splitting','on');
                r = roots(f_cheb);
                f = f_smallnu;
                f_cheb = chebfun(f,[x(xcutoffIndex) bounds(2)] ,'splitting','on');
                r = [r; roots(f_cheb)];
            end
        end
        
        function h0 = BarotropicEquivalentDepthAtWavenumber(self, k)
            % this function estimates the location of the root
            f = @(k) self.b*self.N0./sqrt(self.g*tanh(max(k,1e-15)*self.Lz)./max(k,1e-15));
            
            epsilon = self.f0/self.N0;
            lambda = k*self.b;
            nu = @(x) sqrt( epsilon^2 * x.^2 + lambda^2 );
            s = @(x) x;
            x_nu = lambda/sqrt(5*5*exp(-2*self.Lz/self.b) - epsilon*epsilon);
            
            r = self.FindRootsInRange(nu,s,[0.95 1.05]*f(k),x_nu);
            h0 = (self.b*self.N0./r).^2/self.g;
        end
        
        function h0 = BarotropicEquivalentDepthAtFrequency(self, omega)
            % this function estimates the location of the root
            f = @(omega) max( self.b*self.N0*omega/self.g, self.b*self.N0/sqrt(self.g*self.Lz));
            
            nu = @(x) omega*x/self.N0;
            s = @(x) x;
            x_nu = Inf;
            
            r = self.FindRootsInRange(nu, s, [0.95 1.5]*f(omega), x_nu);
            h0 = (self.b*self.N0./r).^2/self.g;
        end
                
        function [psi] = SurfaceModesAtWavenumber(self, k)
            % See LaCasce 2012.
            % size(psi) = [size(k); length(z)]
            sizeK = size(k);
            if length(sizeK) == 2 && sizeK(2) == 1
                sizeK(2) = [];
            end
            k = reshape(k,[],1);
            zCoord = reshape(self.z,1,[]);
            
            alpha = 2/self.b;
            eta = self.N0*k/(alpha*self.f0);
            H = self.Lz;
            
            numerator = besselk(0,2*eta*exp(-alpha*H/2)) .* besseli(1,2*eta*exp(alpha*zCoord/2)) + besseli(0,2*eta*exp(-alpha*H/2)) .* besselk(1,2*eta*exp(alpha*zCoord/2));
            denominator = besseli(0,2*eta) .* besselk(0,2*eta*exp(-alpha*H/2)) - besselk(0,2*eta) .* besseli(0,2*eta*exp(-alpha*H/2));
            psi = (1./(eta*alpha*self.f0)) .* exp(alpha*zCoord/2) .* numerator ./ denominator;
            
            sizeK(end+1) = length(self.z);
            psi = reshape(psi,sizeK);
        end
        
        function [psi] = BottomModesAtWavenumber(self, k)
            % Not done in LaCasce 2012, but the calculation is almost
            % identical.
            % size(psi) = [size(k); length(z)]
            sizeK = size(k);
            if length(sizeK) == 2 && sizeK(2) == 1
                sizeK(2) = [];
            end
            k = reshape(k,[],1);
            zCoord = reshape(self.z,1,[]);
            
            alpha = 2/self.b;
            eta = self.N0*k/(alpha*self.f0);
            H = self.Lz;
            
            numerator = besselk(0,2*eta) .* besseli(1,2*eta*exp(alpha*zCoord/2)) + besseli(0,2*eta) .* besselk(1,2*eta*exp(alpha*zCoord/2));
            denominator = besselk(0,2*eta) .* besseli(0,2*eta*exp(-alpha*H/2)) - besseli(0,2*eta) .* besselk(0,2*eta*exp(-alpha*H/2));
            
            psi = (1./(eta*alpha*self.f0)) .* exp(alpha*(zCoord+2*H)/2) .* numerator ./ denominator;
            
            sizeK(end+1) = length(self.z);
            psi = reshape(psi,sizeK);
        end
        
        function [F,G] = ModeFunctionsForOmegaAndC(self,omega,c)
            if self.shouldApproximate(omega,c) == 1
                G = self.GSolutionApprox;
                F = self.FSolutionApprox;
            else
                G = self.GSolution;
                F = self.FSolution;
            end
        end
        
        function [F,G] = NormalizedModesForOmegaAndC(self,omega,c)
            F = zeros(length(self.z),length(c));
            G = zeros(length(self.z),length(c));
            
            for j=1:length(c)
                if omega(j) < self.N0
                    lowerIntegrationBound = max(5*self.b*log(omega(j)/self.N0),-self.Lz);
                else
                    lowerIntegrationBound = max(-self.Lz,-4*c(j)/omega(j));
                end
                [Ffunc,Gfunc] = self.ModeFunctionsForOmegaAndC(omega(j),c(j));
                switch self.normalization
                    case Normalization.uMax
                        % Doesn't the surface have the maximum value???
                        A = Ffunc(0,omega(j),c(j));
                    case Normalization.wMax
                        A = max( abs( Gfunc(linspace(lowerIntegrationBound,0,5000), omega(j), c(j) ) )  );
                    case Normalization.kConstant
                        A = sqrt(Gfunc(0,omega(j),c(j))^2 + integral( @(z) (self.N0^2*exp(2*z/self.b) - self.f0^2).*Gfunc(z,omega(j),c(j)).^2,lowerIntegrationBound,0)/self.g);
                    case Normalization.omegaConstant
                        A = sqrt(integral( @(z) Ffunc(z,omega(j),c(j)).^2,lowerIntegrationBound,0)/self.Lz);
                end
                if Ffunc(0,omega(j),c(j)) < 0
                    A = -A;
                end
                F(:,j) = Ffunc(self.z,omega(j),c(j))/A;
                G(:,j) = Gfunc(self.z,omega(j),c(j))/A;
            end
        end
       
        function A = kConstantNormalizationForOmegaAndC(self,omega,c)
            nu = self.b*omega/c;
            f = @(s) s*s*(besselj(nu,s).^2 - besselj(nu-1,s)*besselj(nu+1,s))/2;
            g = @(s) (((s/2).^(2*nu))/(2*(nu^3)*gamma(nu)^2)) * genHyper([nu, nu+1/2],[nu+1,nu+1,2*nu+1],-s*s);
            s0 = self.N0 * self.b / c;
            sD = s0 * exp(-self.Lz/self.b);
            A2inv = (c*c/self.b * (f(s0)-f(sD)) - self.b*self.f0*self.f0 * (g(s0)-g(sD)) )/self.g;
            A = sqrt(A2inv);
        end
        
    end
    
    methods (Access = protected)
        function self = InitializeWithGrid(self, rho, zIn)
            if isempty(self.nModes) || self.nModes < 1
                self.nModes = 64;
            end
        end
        
        function self = InitializeWithFunction(self, rho, zMin, zMax, zOut)
            if isempty(self.nModes) || self.nModes < 1
                self.nModes = 64;
            end
        end
    end
    
end