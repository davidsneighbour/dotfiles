package main

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type row struct {
	ID   string
	Name string
}

type model struct {
	rows      []row
	nameOnly  bool
	headStyle lipgloss.Style
	rowStyle  lipgloss.Style
}

func initialModel(rows []row, nameOnly bool) model {
	return model{
		rows:     rows,
		nameOnly: nameOnly,
		headStyle: lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("63")),
		rowStyle: lipgloss.NewStyle().Foreground(lipgloss.Color("252")),
	}
}

func (m model) Init() tea.Cmd {
	return nil
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c", "esc", "enter":
			return m, tea.Quit
		}
	}
	return m, nil
}

func (m model) View() string {
	var b strings.Builder
	if m.nameOnly {
		b.WriteString(m.headStyle.Render("Configured workspaces (name mode)"))
		b.WriteString("\n\n")
		for _, r := range m.rows {
			b.WriteString(m.rowStyle.Render("• " + r.Name))
			b.WriteString("\n")
		}
	} else {
		b.WriteString(m.headStyle.Render("Configured workspaces"))
		b.WriteString("\n\n")
		b.WriteString(m.headStyle.Render(fmt.Sprintf("%-4s %s", "ID", "Name")))
		b.WriteString("\n")
		for _, r := range m.rows {
			b.WriteString(m.rowStyle.Render(fmt.Sprintf("%-4s %s", r.ID, r.Name)))
			b.WriteString("\n")
		}
	}

	b.WriteString("\n")
	b.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color("241")).Render("Press q, esc, enter, or ctrl+c to close."))
	return b.String()
}

func main() {
	nameOnly := false
	for _, arg := range os.Args[1:] {
		if arg == "--name-only" {
			nameOnly = true
		}
	}

	rows := []row{}
	scanner := bufio.NewScanner(os.Stdin)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}

		parts := strings.SplitN(line, "\t", 2)
		if len(parts) == 2 {
			rows = append(rows, row{ID: parts[0], Name: parts[1]})
			continue
		}

		rows = append(rows, row{ID: "-", Name: line})
	}

	if err := scanner.Err(); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: failed to read input: %v\n", err)
		os.Exit(1)
	}

	p := tea.NewProgram(initialModel(rows, nameOnly), tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: failed to render Bubble Tea view: %v\n", err)
		os.Exit(1)
	}
}
