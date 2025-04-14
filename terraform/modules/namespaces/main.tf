# Define the namespaces required by various components

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      "name" = "monitoring"
      # Add any standard labels used across your namespaces
    }
  }
}

resource "kubernetes_namespace" "data" {
  metadata {
    name = "data"
    labels = {
      "name" = "data"
      # Add any standard labels used across your namespaces
    }
  }
}

resource "kubernetes_namespace" "logging" {
  metadata {
    name = "logging"
    labels = {
      "name" = "logging"
      # Add any standard labels used across your namespaces
    }
  }
}

resource "kubernetes_namespace" "security" {
  metadata {
    name = "security"
    labels = {
      "name" = "security"
      # Add any standard labels used across your namespaces
    }
  }
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      "name" = "argocd"
      # Add any standard labels used across your namespaces
    }
  }
}

resource "kubernetes_namespace" "app" {
  metadata {
    name = "app"
    labels = {
      "name" = "app"
      # Add any standard labels used across your namespaces
    }
  }
}
