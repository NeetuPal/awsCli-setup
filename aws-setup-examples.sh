#!/bin/bash
# AWS CLI Configuration Examples for Terraform

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if AWS CLI is installed
check_aws_cli() {
    print_header "Checking AWS CLI Installation"
    
    if command -v aws &> /dev/null; then
        AWS_VERSION=$(aws --version)
        print_success "AWS CLI is installed: $AWS_VERSION"
    else
        print_error "AWS CLI is not installed"
        echo "Install AWS CLI:"
        echo "  macOS: brew install awscli"
        echo "  Linux: curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip' && unzip awscliv2.zip && sudo ./aws/install"
        echo "  Windows: Download from https://aws.amazon.com/cli/"
        exit 1
    fi
}

# Method 1: Basic AWS Configure
setup_basic_configure() {
    print_header "Method 1: Basic AWS Configure"
    
    echo "This will configure the default AWS profile"
    read -p "Do you want to configure AWS CLI now? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        aws configure
        print_success "AWS CLI configured successfully"
        
        # Test configuration
        if aws sts get-caller-identity &> /dev/null; then
            print_success "Configuration test passed"
        else
            print_error "Configuration test failed"
        fi
    else
        echo "Skipping basic configuration"
    fi
}

# Method 2: Profile-based Configuration
setup_profiles() {
    print_header "Method 2: Profile-based Configuration"
    
    echo "Available profiles:"
    aws configure list-profiles 2>/dev/null || echo "No profiles configured yet"
    
    read -p "Enter profile name to configure (or press Enter to skip): " PROFILE_NAME
    
    if [[ -n "$PROFILE_NAME" ]]; then
        aws configure --profile "$PROFILE_NAME"
        print_success "Profile '$PROFILE_NAME' configured"
        
        # Test profile
        if aws sts get-caller-identity --profile "$PROFILE_NAME" &> /dev/null; then
            print_success "Profile test passed"
        else
            print_error "Profile test failed"
        fi
    fi
}

# Method 3: Environment Variables
setup_environment_variables() {
    print_header "Method 3: Environment Variables"
    
    read -p "Enter AWS Access Key ID: " AWS_ACCESS_KEY_ID
    read -s -p "Enter AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
    echo
    read -p "Enter AWS Region (default: us-west-2): " AWS_REGION
    AWS_REGION=${AWS_REGION:-us-west-2}
    
    # Create environment file
    cat > .env.aws << EOF
# AWS Configuration for Terraform
export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION="$AWS_REGION"
EOF
    
    print_success "Environment file created: .env.aws"
    print_warning "To use: source .env.aws"
    
    # Test environment variables
    source .env.aws
    if aws sts get-caller-identity &> /dev/null; then
        print_success "Environment variables test passed"
    else
        print_error "Environment variables test failed"
    fi
}

# Method 4: AWS SSO Setup
setup_aws_sso() {
    print_header "Method 4: AWS SSO Configuration"
    
    read -p "Do you want to configure AWS SSO? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter SSO profile name: " SSO_PROFILE
        aws configure sso --profile "$SSO_PROFILE"
        
        print_success "SSO profile '$SSO_PROFILE' configured"
        print_warning "To login: aws sso login --profile $SSO_PROFILE"
    fi
}

# Method 5: Assume Role Setup
setup_assume_role() {
    print_header "Method 5: Assume Role Configuration"
    
    read -p "Enter Role ARN to assume: " ROLE_ARN
    read -p "Enter session name: " SESSION_NAME
    
    if [[ -n "$ROLE_ARN" && -n "$SESSION_NAME" ]]; then
        echo "Assuming role..."
        CREDENTIALS=$(aws sts assume-role \
            --role-arn "$ROLE_ARN" \
            --role-session-name "$SESSION_NAME" \
            --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
            --output text)
        
        if [[ $? -eq 0 ]]; then
            read -r ACCESS_KEY SECRET_KEY SESSION_TOKEN <<< "$CREDENTIALS"
            
            cat > .env.assume-role << EOF
# Temporary credentials from assume role
export AWS_ACCESS_KEY_ID="$ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$SECRET_KEY"
export AWS_SESSION_TOKEN="$SESSION_TOKEN"
export AWS_DEFAULT_REGION="us-west-2"
EOF
            
            print_success "Temporary credentials saved to .env.assume-role"
            print_warning "These credentials are temporary and will expire"
        else
            print_error "Failed to assume role"
        fi
    fi
}

# Display current configuration
show_current_config() {
    print_header "Current AWS Configuration"
    
    echo "Configuration list:"
    aws configure list
    
    echo -e "\nCaller identity:"
    aws sts get-caller-identity 2>/dev/null || print_error "Unable to get caller identity"
    
    echo -e "\nAvailable profiles:"
    aws configure list-profiles 2>/dev/null || echo "No profiles found"
    
    echo -e "\nEnvironment variables:"
    env | grep AWS_ || echo "No AWS environment variables set"
}

# Create Terraform provider examples
create_terraform_examples() {
    print_header "Creating Terraform Provider Examples"
    
    # Default provider
    cat > terraform-provider-default.tf << 'EOF'
# Default provider - uses AWS CLI configuration
provider "aws" {
  region = var.aws_region
}
EOF
    
    # Profile-based provider
    cat > terraform-provider-profile.tf << 'EOF'
# Profile-based provider
provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}
EOF
    
    # Environment variables provider
    cat > terraform-provider-env.tf << 'EOF'
# Environment variables provider
provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region
}
EOF
    
    # Multiple providers
    cat > terraform-provider-multiple.tf << 'EOF'
# Multiple provider configuration
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

provider "aws" {
  alias   = "production"
  profile = "production"
  region  = "us-west-2"
}

provider "aws" {
  alias   = "staging"
  profile = "staging"
  region  = "us-west-1"
}
EOF
    
    print_success "Terraform provider examples created"
}

# Main menu
main_menu() {
    while true; do
        print_header "AWS CLI Configuration for Terraform"
        echo "1. Check AWS CLI installation"
        echo "2. Basic AWS configure"
        echo "3. Profile-based configuration"
        echo "4. Environment variables setup"
        echo "5. AWS SSO setup"
        echo "6. Assume role setup"
        echo "7. Show current configuration"
        echo "8. Create Terraform provider examples"
        echo "9. Exit"
        
        read -p "Choose an option (1-9): " choice
        
        case $choice in
            1) check_aws_cli ;;
            2) setup_basic_configure ;;
            3) setup_profiles ;;
            4) setup_environment_variables ;;
            5) setup_aws_sso ;;
            6) setup_assume_role ;;
            7) show_current_config ;;
            8) create_terraform_examples ;;
            9) echo "Goodbye!"; exit 0 ;;
            *) print_error "Invalid option" ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Run main menu
main_menu