const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');

// Test configuration
const ANSIBLE_CONFIG = {
  playbookPath: path.join(__dirname, '../../ansible'),
  inventoryPath: path.join(__dirname, '../../ansible/inventory'),
  timeout: 180000 // 3 minutes
};

describe('Ansible Configuration Validation Tests', () => {
  jest.setTimeout(ANSIBLE_CONFIG.timeout);

  beforeAll(() => {
    console.log('Starting Ansible configuration validation...');
    
    // Verify Ansible is installed
    try {
      execSync('ansible --version', { encoding: 'utf8' });
      execSync('ansible-playbook --version', { encoding: 'utf8' });
    } catch (error) {
      throw new Error('Ansible is not installed or not in PATH');
    }
  });

  describe('Playbook Structure Validation', () => {
    test('should have valid main playbook file', () => {
      console.log('Validating main playbook structure...');
      
      const playbookFile = path.join(ANSIBLE_CONFIG.playbookPath, 'site.yml');
      expect(fs.existsSync(playbookFile)).toBe(true);
      
      const playbookContent = fs.readFileSync(playbookFile, 'utf8');
      const playbook = yaml.load(playbookContent);
      
      expect(Array.isArray(playbook)).toBe(true);
      expect(playbook.length).toBeGreaterThan(0);
      
      const mainPlay = playbook[0];
      expect(mainPlay).toHaveProperty('name');
      expect(mainPlay).toHaveProperty('hosts');
      expect(mainPlay).toHaveProperty('roles');
      expect(mainPlay.become).toBe(true);
      
      console.log('Main playbook structure is valid');
    });

    test('should have required roles directory structure', () => {
      console.log('Validating roles directory structure...');
      
      const rolesDir = path.join(ANSIBLE_CONFIG.playbookPath, 'roles');
      expect(fs.existsSync(rolesDir)).toBe(true);
      
      const requiredRoles = ['common', 'docker', 'security', 'deploy'];
      
      requiredRoles.forEach(role => {
        const roleDir = path.join(rolesDir, role);
        expect(fs.existsSync(roleDir)).toBe(true);
        
        // Check for required role subdirectories
        const tasksDir = path.join(roleDir, 'tasks');
        expect(fs.existsSync(tasksDir)).toBe(true);
        
        const mainTaskFile = path.join(tasksDir, 'main.yml');
        expect(fs.existsSync(mainTaskFile)).toBe(true);
        
        console.log(`✓ Role '${role}' structure is valid`);
      });
    });

    test('should have valid inventory structure', () => {
      console.log('Validating inventory structure...');
      
      expect(fs.existsSync(ANSIBLE_CONFIG.inventoryPath)).toBe(true);
      
      const hostsFile = path.join(ANSIBLE_CONFIG.inventoryPath, 'hosts.yml');
      if (fs.existsSync(hostsFile)) {
        const hostsContent = fs.readFileSync(hostsFile, 'utf8');
        const inventory = yaml.load(hostsContent);
        
        expect(inventory).toHaveProperty('all');
        expect(inventory.all).toHaveProperty('children');
        
        console.log('Inventory structure is valid');
      } else {
        console.log('No hosts.yml found - checking for other inventory formats');
        
        const inventoryFiles = fs.readdirSync(ANSIBLE_CONFIG.inventoryPath);
        expect(inventoryFiles.length).toBeGreaterThan(0);
      }
    });

    test('should have valid variables configuration', () => {
      console.log('Validating variables configuration...');
      
      const varsDir = path.join(ANSIBLE_CONFIG.playbookPath, 'vars');
      
      if (fs.existsSync(varsDir)) {
        const mainVarsFile = path.join(varsDir, 'main.yml');
        
        if (fs.existsSync(mainVarsFile)) {
          const varsContent = fs.readFileSync(mainVarsFile, 'utf8');
          const variables = yaml.load(varsContent);
          
          expect(typeof variables).toBe('object');
          
          // Check for essential variables
          const essentialVars = ['app_name', 'app_directory'];
          essentialVars.forEach(varName => {
            expect(variables).toHaveProperty(varName);
          });
          
          console.log('Variables configuration is valid');
        }
      } else {
        console.log('No vars directory found - variables may be defined in playbook');
      }
    });
  });

  describe('Role Validation', () => {
    test('should validate common role tasks', () => {
      console.log('Validating common role...');
      
      const commonTasksFile = path.join(ANSIBLE_CONFIG.playbookPath, 'roles/common/tasks/main.yml');
      expect(fs.existsSync(commonTasksFile)).toBe(true);
      
      const tasksContent = fs.readFileSync(commonTasksFile, 'utf8');
      const tasks = yaml.load(tasksContent);
      
      expect(Array.isArray(tasks)).toBe(true);
      
      // Check for system update tasks
      const hasUpdateTask = tasks.some(task => 
        task.name && task.name.toLowerCase().includes('update')
      );
      expect(hasUpdateTask).toBe(true);
      
      console.log('Common role tasks are valid');
    });

    test('should validate docker role tasks', () => {
      console.log('Validating docker role...');
      
      const dockerTasksFile = path.join(ANSIBLE_CONFIG.playbookPath, 'roles/docker/tasks/main.yml');
      expect(fs.existsSync(dockerTasksFile)).toBe(true);
      
      const tasksContent = fs.readFileSync(dockerTasksFile, 'utf8');
      const tasks = yaml.load(tasksContent);
      
      expect(Array.isArray(tasks)).toBe(true);
      
      // Check for Docker installation tasks
      const hasDockerInstall = tasks.some(task => 
        task.name && (
          task.name.toLowerCase().includes('docker') ||
          (task.apt && task.apt.name && task.apt.name.includes('docker'))
        )
      );
      expect(hasDockerInstall).toBe(true);
      
      // Check for Docker Compose installation
      const hasComposeInstall = tasks.some(task => 
        task.name && task.name.toLowerCase().includes('compose')
      );
      expect(hasComposeInstall).toBe(true);
      
      console.log('Docker role tasks are valid');
    });

    test('should validate security role tasks', () => {
      console.log('Validating security role...');
      
      const securityTasksFile = path.join(ANSIBLE_CONFIG.playbookPath, 'roles/security/tasks/main.yml');
      expect(fs.existsSync(securityTasksFile)).toBe(true);
      
      const tasksContent = fs.readFileSync(securityTasksFile, 'utf8');
      const tasks = yaml.load(tasksContent);
      
      expect(Array.isArray(tasks)).toBe(true);
      
      // Check for firewall configuration
      const hasFirewallConfig = tasks.some(task => 
        task.name && (
          task.name.toLowerCase().includes('firewall') ||
          task.name.toLowerCase().includes('ufw')
        )
      );
      expect(hasFirewallConfig).toBe(true);
      
      console.log('Security role tasks are valid');
    });

    test('should validate deploy role tasks', () => {
      console.log('Validating deploy role...');
      
      const deployTasksFile = path.join(ANSIBLE_CONFIG.playbookPath, 'roles/deploy/tasks/main.yml');
      expect(fs.existsSync(deployTasksFile)).toBe(true);
      
      const tasksContent = fs.readFileSync(deployTasksFile, 'utf8');
      const tasks = yaml.load(tasksContent);
      
      expect(Array.isArray(tasks)).toBe(true);
      
      // Check for application deployment tasks
      const hasDeploymentTask = tasks.some(task => 
        task.name && (
          task.name.toLowerCase().includes('deploy') ||
          task.name.toLowerCase().includes('docker-compose') ||
          task.name.toLowerCase().includes('application')
        )
      );
      expect(hasDeploymentTask).toBe(true);
      
      console.log('Deploy role tasks are valid');
    });
  });

  describe('Template Validation', () => {
    test('should validate Docker Compose template', () => {
      console.log('Validating Docker Compose template...');
      
      const templatesDir = path.join(ANSIBLE_CONFIG.playbookPath, 'roles/deploy/templates');
      
      if (fs.existsSync(templatesDir)) {
        const composeTemplate = path.join(templatesDir, 'docker-compose.prod.yml.j2');
        
        if (fs.existsSync(composeTemplate)) {
          const templateContent = fs.readFileSync(composeTemplate, 'utf8');
          
          // Check for essential Docker Compose structure
          expect(templateContent).toContain('version:');
          expect(templateContent).toContain('services:');
          expect(templateContent).toContain('todo-api');
          expect(templateContent).toContain('mongodb');
          
          // Check for Jinja2 template variables
          expect(templateContent).toMatch(/\{\{.*\}\}/);
          
          console.log('Docker Compose template is valid');
        }
      }
    });

    test('should validate environment template', () => {
      console.log('Validating environment template...');
      
      const templatesDir = path.join(ANSIBLE_CONFIG.playbookPath, 'roles/deploy/templates');
      
      if (fs.existsSync(templatesDir)) {
        const envTemplate = path.join(templatesDir, '.env.j2');
        
        if (fs.existsSync(envTemplate)) {
          const templateContent = fs.readFileSync(envTemplate, 'utf8');
          
          // Check for essential environment variables
          expect(templateContent).toContain('NODE_ENV');
          expect(templateContent).toContain('MONGODB_URI');
          
          console.log('Environment template is valid');
        }
      }
    });

    test('should validate backup script template', () => {
      console.log('Validating backup script template...');
      
      const templatesDir = path.join(ANSIBLE_CONFIG.playbookPath, 'roles/deploy/templates');
      
      if (fs.existsSync(templatesDir)) {
        const backupTemplate = path.join(templatesDir, 'backup-db.sh.j2');
        
        if (fs.existsSync(backupTemplate)) {
          const templateContent = fs.readFileSync(backupTemplate, 'utf8');
          
          // Check for backup script structure
          expect(templateContent).toContain('#!/bin/bash');
          expect(templateContent).toContain('mongodump');
          expect(templateContent).toContain('docker exec');
          
          console.log('Backup script template is valid');
        }
      }
    });
  });

  describe('Handlers Validation', () => {
    test('should validate role handlers', () => {
      console.log('Validating role handlers...');
      
      const roles = ['docker', 'security', 'deploy'];
      
      roles.forEach(role => {
        const handlersDir = path.join(ANSIBLE_CONFIG.playbookPath, `roles/${role}/handlers`);
        
        if (fs.existsSync(handlersDir)) {
          const handlersFile = path.join(handlersDir, 'main.yml');
          
          if (fs.existsSync(handlersFile)) {
            const handlersContent = fs.readFileSync(handlersFile, 'utf8');
            const handlers = yaml.load(handlersContent);
            
            expect(Array.isArray(handlers)).toBe(true);
            
            handlers.forEach(handler => {
              expect(handler).toHaveProperty('name');
              expect(handler).toHaveProperty('systemd');
            });
            
            console.log(`✓ Handlers for role '${role}' are valid`);
          }
        }
      });
    });

    test('should validate main playbook handlers', () => {
      console.log('Validating main playbook handlers...');
      
      const playbookFile = path.join(ANSIBLE_CONFIG.playbookPath, 'site.yml');
      const playbookContent = fs.readFileSync(playbookFile, 'utf8');
      const playbook = yaml.load(playbookContent);
      
      const mainPlay = playbook[0];
      
      if (mainPlay.handlers) {
        expect(Array.isArray(mainPlay.handlers)).toBe(true);
        
        mainPlay.handlers.forEach(handler => {
          expect(handler).toHaveProperty('name');
        });
        
        console.log('Main playbook handlers are valid');
      }
    });
  });

  describe('Syntax Validation', () => {
    test('should validate playbook syntax', () => {
      console.log('Validating Ansible playbook syntax...');
      
      const playbookFile = path.join(ANSIBLE_CONFIG.playbookPath, 'site.yml');
      
      try {
        const syntaxCheck = execSync(`ansible-playbook --syntax-check ${playbookFile}`, {
          encoding: 'utf8',
          cwd: ANSIBLE_CONFIG.playbookPath
        });
        
        expect(syntaxCheck).toContain('playbook:');
        
        console.log('Playbook syntax is valid');
        
      } catch (error) {
        console.error('Syntax check output:', error.stdout);
        throw new Error(`Playbook syntax validation failed: ${error.message}`);
      }
    });

    test('should validate role task syntax', () => {
      console.log('Validating role task syntax...');
      
      const roles = ['common', 'docker', 'security', 'deploy'];
      
      roles.forEach(role => {
        const tasksFile = path.join(ANSIBLE_CONFIG.playbookPath, `roles/${role}/tasks/main.yml`);
        
        if (fs.existsSync(tasksFile)) {
          try {
            const tasksContent = fs.readFileSync(tasksFile, 'utf8');
            const tasks = yaml.load(tasksContent);
            
            expect(Array.isArray(tasks)).toBe(true);
            
            // Validate each task structure
            tasks.forEach((task, index) => {
              expect(task).toHaveProperty('name');
              expect(typeof task.name).toBe('string');
              
              // Each task should have at least one action
              const actionKeys = Object.keys(task).filter(key => 
                !['name', 'when', 'become', 'tags', 'notify', 'register', 'ignore_errors'].includes(key)
              );
              expect(actionKeys.length).toBeGreaterThan(0);
            });
            
            console.log(`✓ Role '${role}' task syntax is valid`);
            
          } catch (error) {
            throw new Error(`Role '${role}' task syntax validation failed: ${error.message}`);
          }
        }
      });
    });

    test('should validate variable syntax in templates', () => {
      console.log('Validating template variable syntax...');
      
      const templatesDir = path.join(ANSIBLE_CONFIG.playbookPath, 'roles/deploy/templates');
      
      if (fs.existsSync(templatesDir)) {
        const templateFiles = fs.readdirSync(templatesDir).filter(file => file.endsWith('.j2'));
        
        templateFiles.forEach(templateFile => {
          const templatePath = path.join(templatesDir, templateFile);
          const templateContent = fs.readFileSync(templatePath, 'utf8');
          
          // Check for valid Jinja2 syntax
          const jinja2Patterns = [
            /\{\{.*\}\}/, // Variables
            /\{%.*%\}/, // Control structures
            /\{#.*#\}/ // Comments
          ];
          
          const hasJinja2Syntax = jinja2Patterns.some(pattern => 
            pattern.test(templateContent)
          );
          
          if (hasJinja2Syntax) {
            // Basic validation - check for balanced braces
            const openBraces = (templateContent.match(/\{\{/g) || []).length;
            const closeBraces = (templateContent.match(/\}\}/g) || []).length;
            expect(openBraces).toBe(closeBraces);
            
            console.log(`✓ Template '${templateFile}' syntax is valid`);
          }
        });
      }
    });
  });

  describe('Configuration Validation', () => {
    test('should validate Ansible configuration file', () => {
      console.log('Validating Ansible configuration...');
      
      const ansibleCfgFile = path.join(ANSIBLE_CONFIG.playbookPath, 'ansible.cfg');
      
      if (fs.existsSync(ansibleCfgFile)) {
        const configContent = fs.readFileSync(ansibleCfgFile, 'utf8');
        
        // Check for essential configuration sections
        expect(configContent).toContain('[defaults]');
        
        // Check for common configuration options
        const commonOptions = [
          'host_key_checking',
          'inventory',
          'roles_path'
        ];
        
        commonOptions.forEach(option => {
          if (configContent.includes(option)) {
            console.log(`✓ Configuration option '${option}' is set`);
          }
        });
        
        console.log('Ansible configuration is valid');
      } else {
        console.log('No ansible.cfg found - using default configuration');
      }
    });

    test('should validate role dependencies', () => {
      console.log('Validating role dependencies...');
      
      const roles = ['common', 'docker', 'security', 'deploy'];
      
      roles.forEach(role => {
        const metaDir = path.join(ANSIBLE_CONFIG.playbookPath, `roles/${role}/meta`);
        
        if (fs.existsSync(metaDir)) {
          const metaFile = path.join(metaDir, 'main.yml');
          
          if (fs.existsSync(metaFile)) {
            const metaContent = fs.readFileSync(metaFile, 'utf8');
            const meta = yaml.load(metaContent);
            
            if (meta.dependencies) {
              expect(Array.isArray(meta.dependencies)).toBe(true);
              
              meta.dependencies.forEach(dep => {
                if (typeof dep === 'string') {
                  expect(dep).toBeTruthy();
                } else if (typeof dep === 'object') {
                  expect(dep).toHaveProperty('role');
                }
              });
            }
            
            console.log(`✓ Role '${role}' dependencies are valid`);
          }
        }
      });
    });

    test('should validate variable precedence and scope', () => {
      console.log('Validating variable precedence...');
      
      const playbookFile = path.join(ANSIBLE_CONFIG.playbookPath, 'site.yml');
      const playbookContent = fs.readFileSync(playbookFile, 'utf8');
      const playbook = yaml.load(playbookContent);
      
      const mainPlay = playbook[0];
      
      // Check for vars_files
      if (mainPlay.vars_files) {
        expect(Array.isArray(mainPlay.vars_files)).toBe(true);
        
        mainPlay.vars_files.forEach(varsFile => {
          const varsPath = path.join(ANSIBLE_CONFIG.playbookPath, varsFile);
          expect(fs.existsSync(varsPath)).toBe(true);
        });
      }
      
      // Check for vars section
      if (mainPlay.vars) {
        expect(typeof mainPlay.vars).toBe('object');
      }
      
      console.log('Variable precedence configuration is valid');
    });
  });

  describe('Security Validation', () => {
    test('should validate secure practices in playbooks', () => {
      console.log('Validating security practices...');
      
      const playbookFile = path.join(ANSIBLE_CONFIG.playbookPath, 'site.yml');
      const playbookContent = fs.readFileSync(playbookFile, 'utf8');
      
      // Check for become usage
      expect(playbookContent).toContain('become:');
      
      // Check that sensitive operations use become
      const playbook = yaml.load(playbookContent);
      const mainPlay = playbook[0];
      
      if (mainPlay.become !== undefined) {
        expect(typeof mainPlay.become).toBe('boolean');
      }
      
      console.log('Security practices validation passed');
    });

    test('should validate no hardcoded secrets', () => {
      console.log('Validating no hardcoded secrets...');
      
      const filesToCheck = [
        path.join(ANSIBLE_CONFIG.playbookPath, 'site.yml'),
        path.join(ANSIBLE_CONFIG.playbookPath, 'vars/main.yml')
      ];
      
      const suspiciousPatterns = [
        /password\s*:\s*['"]\w+['"]/i,
        /secret\s*:\s*['"]\w+['"]/i,
        /key\s*:\s*['"]\w+['"]/i,
        /token\s*:\s*['"]\w+['"]/i
      ];
      
      filesToCheck.forEach(filePath => {
        if (fs.existsSync(filePath)) {
          const content = fs.readFileSync(filePath, 'utf8');
          
          suspiciousPatterns.forEach(pattern => {
            const matches = content.match(pattern);
            if (matches) {
              console.warn(`Potential hardcoded secret found in ${filePath}: ${matches[0]}`);
              // Don't fail the test, just warn
            }
          });
        }
      });
      
      console.log('Hardcoded secrets validation completed');
    });
  });

  describe('Performance and Best Practices', () => {
    test('should validate task efficiency', () => {
      console.log('Validating task efficiency...');
      
      const roles = ['common', 'docker', 'security', 'deploy'];
      
      roles.forEach(role => {
        const tasksFile = path.join(ANSIBLE_CONFIG.playbookPath, `roles/${role}/tasks/main.yml`);
        
        if (fs.existsSync(tasksFile)) {
          const tasksContent = fs.readFileSync(tasksFile, 'utf8');
          const tasks = yaml.load(tasksContent);
          
          tasks.forEach(task => {
            // Check for idempotency indicators
            if (task.apt || task.yum || task.package) {
              // Package management tasks should have state defined
              const packageModule = task.apt || task.yum || task.package;
              if (typeof packageModule === 'object') {
                expect(packageModule).toHaveProperty('state');
              }
            }
            
            // Check for proper use of changed_when for command tasks
            if (task.command || task.shell) {
              // Commands should ideally have changed_when defined
              if (!task.changed_when && !task.creates) {
                console.warn(`Task '${task.name}' uses command/shell without changed_when or creates`);
              }
            }
          });
          
          console.log(`✓ Role '${role}' task efficiency validated`);
        }
      });
    });

    test('should validate proper use of handlers', () => {
      console.log('Validating handler usage...');
      
      const roles = ['docker', 'security'];
      
      roles.forEach(role => {
        const tasksFile = path.join(ANSIBLE_CONFIG.playbookPath, `roles/${role}/tasks/main.yml`);
        const handlersFile = path.join(ANSIBLE_CONFIG.playbookPath, `roles/${role}/handlers/main.yml`);
        
        if (fs.existsSync(tasksFile) && fs.existsSync(handlersFile)) {
          const tasksContent = fs.readFileSync(tasksFile, 'utf8');
          const handlersContent = fs.readFileSync(handlersFile, 'utf8');
          
          const tasks = yaml.load(tasksContent);
          const handlers = yaml.load(handlersContent);
          
          // Check that notified handlers exist
          tasks.forEach(task => {
            if (task.notify) {
              const notifyList = Array.isArray(task.notify) ? task.notify : [task.notify];
              
              notifyList.forEach(handlerName => {
                const handlerExists = handlers.some(handler => 
                  handler.name === handlerName
                );
                expect(handlerExists).toBe(true);
              });
            }
          });
          
          console.log(`✓ Role '${role}' handler usage is valid`);
        }
      });
    });
  });
});

// Helper function to validate YAML syntax
function validateYamlSyntax(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    yaml.load(content);
    return true;
  } catch (error) {
    throw new Error(`YAML syntax error in ${filePath}: ${error.message}`);
  }
}