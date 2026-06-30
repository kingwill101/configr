#!/bin/sh
cat > /tmp/test_script.sh << 'EOF'
#!/bin/sh
touch /tmp/script_test_marker
EOF
chmod +x /tmp/test_script.sh
